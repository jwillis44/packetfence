package logtailer

import (
	"context"
	"net/http"
	"regexp"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/sharedutils"
	"github.com/jcuga/golongpoll"
)

const maxSessionIdleTime = 5 * time.Minute
const defaultPollTimeout = 30 * time.Second

var handledPath = regexp.MustCompile(`^/api/v1/logs/tail`)

// Register the plugin in caddy
func init() {
	caddy.RegisterPlugin("log-tailer", caddy.Plugin{
		ServerType: "http",
		Action:     setup,
	})
}

type PrettyTokenInfo struct {
	AdminActions []string  `json:"admin_actions"`
	AdminRoles   []string  `json:"admin_roles"`
	TenantId     int       `json:"tenant_id"`
	Username     string    `json:"username"`
	ExpiresAt    time.Time `json:"expires_at"`
}

type LogTailerHandler struct {
	Next                httpserver.Handler
	router              *gin.Engine
	eventsManager       *golongpoll.LongpollManager
	sessions            map[string]*TailingSession
	maintenanceLauncher *sync.Once
}

// Setup the log-tailer middleware
// Also loads the pfconfig resources and registers them in the pool
func setup(c *caddy.Controller) error {
	ctx := log.LoggerNewContext(context.Background())

	logTailer, err := buildLogTailerHandler(ctx)

	if err != nil {
		return err
	}

	httpserver.GetConfig(c).AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		logTailer.Next = next
		return logTailer
	})

	return nil
}

func buildLogTailerHandler(ctx context.Context) (LogTailerHandler, error) {

	logTailer := LogTailerHandler{}

	var err error
	logTailer.eventsManager, err = golongpoll.StartLongpoll(golongpoll.Options{
		LoggingEnabled:     (sharedutils.EnvOrDefault("LOG_LEVEL", "") == "debug"),
		MaxEventBufferSize: 1000,
		// Events stay for up to 5 minutes
		EventTimeToLiveSeconds:         int(maxSessionIdleTime / time.Second),
		DeleteEventAfterFirstRetrieval: true,
	})
	sharedutils.CheckError(err)

	logTailer.sessions = map[string]*TailingSession{}

	logTailer.maintenanceLauncher = &sync.Once{}

	router := gin.Default()
	logTailerApi := router.Group("/api/v1/logs/tail")

	logTailerApi.POST("", logTailer.createNewSession)
	logTailerApi.GET("/:id", logTailer.getSession)
	logTailerApi.DELETE("/:id", logTailer.deleteSession)

	logTailer.router = router

	return logTailer, nil
}

func (h LogTailerHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	ctx := r.Context()

	defer panichandler.Http(ctx, w)

	if handledPath.MatchString(r.URL.Path) {
		h.router.ServeHTTP(w, r)
		return 0, nil
	} else {
		return h.Next.ServeHTTP(w, r)
	}

}

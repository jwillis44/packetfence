package pfdns

import (
	"context"
	"net"
	"sync"
	"time"

	"github.com/coredns/caddy"
    "github.com/coredns/coredns/core/dnsserver"
    "github.com/coredns/coredns/plugin"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/timedlock"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
	cache "github.com/patrickmn/go-cache"
)

func init() {
	GlobalTransactionLock = timedlock.NewRWLock()
	GlobalTransactionLock.Panic = false
	GlobalTransactionLock.PrintErrors = true
	caddy.RegisterPlugin("pfdns", caddy.Plugin{
		ServerType: "dns",
		Action:     setuppfdns,
	})
}

func setuppfdns(c *caddy.Controller) error {
	var pf = &pfdns{}
	var ip net.IP
	pf.Network = make(map[string]net.IP)
	ctx := context.Background()
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.General)
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.CaptivePortal)
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.Interfaces.ListenInts)
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.Interfaces.DNSInts)

	pfconfigdriver.PfconfigPool.Refresh(ctx)

	for c.Next() {
		// block with extra parameters
		for c.NextBlock() {
			switch c.Val() {

			case "redirectTo":
				arg := c.RemainingArgs()
				ip = net.ParseIP(arg[0])
				if ip == nil {
					return c.Errf("Invalid IP address '%s'", c.Val())
				}
			default:
				return c.Errf("Unknown keyword '%s'", c.Val())
			}
		}
	}

	if err := pf.DbInit(ctx); err != nil {
		return c.Errf("pfdns: unable to initialize database connection")
	}
	if err := pf.PassthroughsInit(ctx); err != nil {
		return c.Errf("pfdns: unable to initialize passthrough")
	}
	if err := pf.PassthroughsIsolationInit(ctx); err != nil {
		return c.Errf("pfdns: unable to initialize isolation passthrough")
	}

	if err := pf.WebservicesInit(ctx); err != nil {
		return c.Errf("pfdns: unable to fetch Webservices credentials")
	}

	if err := pf.detectVIP(ctx); err != nil {
		return c.Errf("pfdns: unable to initialize the vip network map")
	}

	if err := pf.DomainPassthroughInit(ctx); err != nil {
		return c.Errf("pfdns: unable to initialize domain passthrough")
	}

	if err := pf.detectType(ctx); err != nil {
		return c.Errf("pfdns: unable to initialize Network Type")
	}

	if err := pf.PortalFQDNInit(ctx); err != nil {
		return c.Errf("pfdns: unable to initialize Portal FQDN")
	}

	if err := pf.MakeDetectionMecanism(ctx); err != nil {
		return c.Errf("pfdns: unable to initialize Detection Mecanism List")
	}

	// Initialize dns filter cache
	pf.DNSFilter = cache.New(300*time.Second, 10*time.Second)

	pf.IpsetCache = cache.New(1*time.Hour, 10*time.Second)

	pf.apiClient = unifiedapiclient.NewFromConfig(context.Background())

	pf.refreshLauncher = &sync.Once{}
	pfconfigdriver.PfconfigPool.AddRefreshable(ctx, pf)

	dnsserver.GetConfig(c).AddPlugin(
		func(next plugin.Handler) plugin.Handler {
			pf.InternalPortalIP = net.ParseIP(pfconfigdriver.Config.PfConf.CaptivePortal.IpAddress).To4()
			pf.RedirectIP = ip
			pf.Next = next
			return pf
		})

	return nil
}

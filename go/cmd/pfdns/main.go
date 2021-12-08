package main

import (

        "github.com/coredns/coredns/coremain"
        "github.com/coredns/coredns/core/dnsserver"
        _ "github.com/coredns/coredns/core/plugin"
	    _ "github.com/inverse-inc/packetfence/go/coredns_pfdns"
	    _ "github.com/inverse-inc/packetfence/go/coredns_logger"
)

func init() {
		i := -1
		for j, d := range dnsserver.Directives {
			if d == "transfer" {
				i = j + 1
				break
			}
		}

        temp := make([]string, 0, len(dnsserver.Directives) + 2)
        temp = append(temp, dnsserver.Directives[:i]...)
        temp = append(temp, "logger", "pfdns")
        temp = append(temp, dnsserver.Directives[i:]...)
        dnsserver.Directives = temp
}

func main() {
        coremain.Run()
}


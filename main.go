package main

import (
	"fmt"
	"log"
	"net"
	"net/http"
	"os"

	consulapi "github.com/hashicorp/consul/api"
)

type Service struct {
	ID     string
	Name   string
	Consul *consulapi.Client
}

func (service *Service) Health(w http.ResponseWriter, r *http.Request) {
	fmt.Fprint(w, "I'm fine. Thank you for asking!")
}

func (service *Service) GetHandler(w http.ResponseWriter, r *http.Request) {
	kv := service.Consul.KV()

	key := r.URL.Query().Get("key")
	pair, _, err := kv.Get(key, nil)
	if err != nil {
		fmt.Fprintln(os.Stderr, err.Error())
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if pair == nil {
		fmt.Fprintln(os.Stderr, fmt.Sprintf("%s = nil", key))
		http.Error(w, "", http.StatusNotFound)
		return
	}
	fmt.Fprintln(os.Stdout, fmt.Sprintf("%s = %s", pair.Key, pair.Value))
	w.Write(pair.Value)
}

func (service *Service) SetHandler(w http.ResponseWriter, r *http.Request) {
	kv := service.Consul.KV()

	for key := range r.URL.Query() {
		p := &consulapi.KVPair{
			Key:   key,
			Value: []byte(r.URL.Query().Get(key)),
		}
		_, err := kv.Put(p, nil)
		if err != nil {
			fmt.Fprintln(os.Stderr, err.Error())
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
	}
	w.Write([]byte("Success"))
}

func GetMyIP() (net.IP, error) {
	udp, err := net.Dial("udp", "8.8.8.8:53")
	if err != nil {
		return nil, err
	}
	defer udp.Close()

	localAddr := udp.LocalAddr()
	udpAddr, err := net.ResolveUDPAddr(localAddr.Network(), localAddr.String())

	return udpAddr.IP, err
}

func main() {
	ip, err := GetMyIP()
	if err != nil {
		fmt.Fprintln(os.Stderr, err.Error())
		os.Exit(1)
	}
	c, err := consulapi.NewClient(consulapi.DefaultConfig())
	if err != nil {
		fmt.Fprintln(os.Stderr, err.Error())
		os.Exit(1)
	}

	service := &Service{
		ID:     "my-service",
		Name:   "my-service",
		Consul: c,
	}

	check := &consulapi.AgentServiceCheck{
		Name:     "/health",
		HTTP:     fmt.Sprintf("http://%s:%s/health", ip.String(), "8080"),
		Interval: "10s",
	}

	registration := &consulapi.AgentServiceRegistration{
		ID:      service.ID,
		Name:    service.Name,
		Address: ip.String(),
		Port:    8080,
		Check:   check,
	}

	err = service.Consul.Agent().ServiceRegister(registration)
	if err != nil {
		fmt.Fprintln(os.Stderr, err.Error())
		os.Exit(1)
	}

	defer service.Consul.Agent().ServiceDeregister(service.ID)

	http.HandleFunc("/health", service.Health)
	http.HandleFunc("/get_value", service.GetHandler)
	http.HandleFunc("/set_value", service.SetHandler)

	log.Fatal(http.ListenAndServe(":8080", nil))
}

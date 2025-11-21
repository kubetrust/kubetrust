package main

import (
	"fmt"
	"html"
	"io"
	"log"
	"net/http"
	"os"
	"time"

	m "github.com/karthick-kk/k8s-mutate-webhook-addca/pkg/mutate"
)

func handleRoot(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "hello %q", html.EscapeString(r.URL.Path))
}

func handleMutate(w http.ResponseWriter, r *http.Request) {
	// read the body / request
	body, err := io.ReadAll(r.Body)
	defer r.Body.Close()

	if err != nil {
		sendError(err, w)
		return
	}

	// mutate the request
	mutated, err := m.Mutate(body, true)
	if err != nil {
		sendError(err, w)
		return
	}

	// and write it back
	w.WriteHeader(http.StatusOK)
	w.Write(mutated)
}

func sendError(err error, w http.ResponseWriter) {
	log.Println(err)
	w.WriteHeader(http.StatusInternalServerError)
	fmt.Fprintf(w, "%s", err)
}

func main() {
	log.Println("Starting server ...")

	// Get TLS certificate paths from environment variables with defaults
	certFile := os.Getenv("TLS_CERT_FILE")
	if certFile == "" {
		certFile = "./ssl/kubetrust.pem" // default for backward compatibility
	}

	keyFile := os.Getenv("TLS_KEY_FILE")
	if keyFile == "" {
		keyFile = "./ssl/kubetrust.key" // default for backward compatibility
	}

	log.Printf("Using TLS cert: %s, key: %s", certFile, keyFile)

	mux := http.NewServeMux()

	mux.HandleFunc("/", handleRoot)
	mux.HandleFunc("/mutate", handleMutate)

	s := &http.Server{
		Addr:           ":8443",
		Handler:        mux,
		ReadTimeout:    10 * time.Second,
		WriteTimeout:   10 * time.Second,
		MaxHeaderBytes: 1 << 20, // 1048576
	}

	log.Fatal(s.ListenAndServeTLS(certFile, keyFile))
}

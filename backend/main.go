package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/redis/go-redis/v9"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

type jsonLogEntry struct {
	Timestamp string `json:"timestamp"`
	Level     string `json:"level"`
	Message   string `json:"message"`
}

func logJSON(level, message string) {
	entry := jsonLogEntry{
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Level:     level,
		Message:   message,
	}
	b, _ := json.Marshal(entry)
	os.Stdout.Write(append(b, '\n'))
}

type healthResponse struct {
	Status string            `json:"status"`
	Checks map[string]string `json:"checks"`
}

var (
	redisClient *redis.Client
	mongoClient *mongo.Client
)

func main() {
	redisHost := os.Getenv("REDIS_HOST")
	mongoURI := os.Getenv("MONGO_URI")

	if redisHost != "" {
		redisClient = redis.NewClient(&redis.Options{Addr: redisHost})
	}

	if mongoURI != "" {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		client, err := mongo.Connect(ctx, options.Client().ApplyURI(mongoURI))
		if err != nil {
			logJSON("error", "failed to connect to MongoDB: "+err.Error())
		} else {
			mongoClient = client
		}
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/api/v1/health", healthHandler)
	mux.HandleFunc("/health", healthHandler)

	port := "8080"
	logJSON("info", "backend starting on port "+port)

	srv := &http.Server{
		Addr:         ":" + port,
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	if err := srv.ListenAndServe(); err != nil {
		logJSON("error", "server error: "+err.Error())
		os.Exit(1)
	}
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	checks := map[string]string{}
	status := "ok"

	if redisClient != nil {
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		if err := redisClient.Ping(ctx).Err(); err != nil {
			checks["redis"] = "unreachable"
			status = "degraded"
		} else {
			checks["redis"] = "ok"
		}
	} else {
		checks["redis"] = "not configured"
	}

	if mongoClient != nil {
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		if err := mongoClient.Ping(ctx, nil); err != nil {
			checks["mongo"] = "unreachable"
			status = "degraded"
		} else {
			checks["mongo"] = "ok"
		}
	} else {
		checks["mongo"] = "not configured"
	}

	w.Header().Set("Content-Type", "application/json")
	if status != "ok" {
		w.WriteHeader(http.StatusServiceUnavailable)
	}
	json.NewEncoder(w).Encode(healthResponse{Status: status, Checks: checks})

	logJSON("info", "health check served, status="+status)
	_ = log.Ldate
}

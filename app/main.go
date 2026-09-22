package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/Azure/AppConfiguration-GoProvider/azureappconfiguration"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
)

type Config struct {
	App struct {
		ImageTag      string
		Message       string
		SecretMessage string
	}
}

func maskSecret(value string) string {
	if len(value) <= 4 {
		return "****"
	}
	return strings.Repeat("*", len(value)-4) + value[len(value)-4:]
}

func main() {
	ctx := context.Background()

	endpoint := os.Getenv("AZURE_APPCONFIG_ENDPOINT")
	if endpoint == "" {
		log.Fatal("AZURE_APPCONFIG_ENDPOINT is not set")
	}

	credential, err := azidentity.NewDefaultAzureCredential(nil)
	if err != nil {
		log.Fatalf("failed to create Azure credential: %v", err)
	}

	options := &azureappconfiguration.Options{
		Selectors: []azureappconfiguration.Selector{
			{
				KeyFilter:   "app:*",
				LabelFilter: "dev",
			},
		},
		KeyVaultOptions: azureappconfiguration.KeyVaultOptions{
			Credential: credential,
		},
	}

	appConfig, err := azureappconfiguration.Load(
		ctx,
		azureappconfiguration.AuthenticationOptions{
			Endpoint:   endpoint,
			Credential: credential,
		},
		options,
	)
	if err != nil {
		log.Fatalf("failed to load App Configuration: %v", err)
	}

	// 検証用の設定全体のログ出力を停止します。解決済みのSecretも含まれ得るためです。
	/*
		raw, err := appConfig.GetBytes(&azureappconfiguration.ConstructionOptions{
			Separator: ":",
		})
		if err != nil {
			log.Fatalf("failed to get raw config: %v", err)
		}
		fmt.Printf("RAW CONFIG: %s\n", string(raw))
	*/

	var config Config
	if err := appConfig.Unmarshal(
		&config,
		&azureappconfiguration.ConstructionOptions{
			Separator: ":",
		},
	); err != nil {
		log.Fatalf("failed to unmarshal configuration: %v", err)
	}

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "App Version: %s\n", config.App.ImageTag)
		fmt.Fprintf(w, "AppConfig Message: %s\n", config.App.Message)
		fmt.Fprintf(w, "KeyVault Secret: %s\n", maskSecret(config.App.SecretMessage))
	})

	log.Println("listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

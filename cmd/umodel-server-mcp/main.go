package main

import (
	"context"
	"flag"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/alibaba/UnifiedModel/internal/bootstrap"
	"github.com/alibaba/UnifiedModel/internal/graphstore"
	"github.com/alibaba/UnifiedModel/internal/mcp"
)

func main() {
	addr := flag.String("addr", ":8080", "HTTP listen address")
	dataRoot := flag.String("data", "data", "UModel data root")
	provider := flag.String("graphstore", graphstore.DefaultProviderType, "GraphStore provider: local.ladybug, memory, file.memory, neo4j (NEO4J_*), or gremlin (GREMLIN_*)")
	uiDir := flag.String("ui-dir", "", "Optional directory containing built UModel web UI assets")
	quickStart := flag.Bool("quickstart", false, "Create a demo workspace and import bundled quickstart data before serving")
	quickStartWorkspace := flag.String("quickstart-workspace", bootstrap.DefaultQuickStartWorkspaceID, "Workspace id used by --quickstart")
	quickStartSample := flag.String("quickstart-sample", bootstrap.DefaultQuickStartSample, "Sample package imported by --quickstart")
	importRoot := flag.String("import-root", "", "Confine UModel API imports to this directory (default: current working directory; use \"/\" to allow any path)")
	flag.Parse()

	graphstoreExplicit := false
	flag.Visit(func(f *flag.Flag) {
		if f.Name == "graphstore" {
			graphstoreExplicit = true
		}
	})
	*provider = resolveProviderForQuickStart(*provider, *quickStart, graphstoreExplicit)

	ctx := context.Background()
	app, err := bootstrap.NewAppWithGraphStore(*dataRoot, graphstore.ProviderConfig{Type: *provider, DataRoot: *dataRoot}, bootstrap.WithImportRoot(*importRoot))
	if err != nil {
		log.Fatal(err)
	}
	defer app.Close()
	if health, err := app.GraphStore.Health(ctx); err != nil {
		log.Fatal(err)
	} else if health.Status == "unavailable" {
		log.Fatalf("graphstore provider %s unavailable: %s", health.Provider, health.Message)
	}
	if *quickStart {
		result, err := app.LoadQuickStart(ctx, bootstrap.QuickStartOptions{
			WorkspaceID: *quickStartWorkspace,
			Sample:      *quickStartSample,
		})
		if err != nil {
			log.Fatalf("quickstart import failed: %v", err)
		}
		log.Printf("quickstart loaded workspace=%s sample=%s umodel_imported=%d umodel_skipped=%d entities=%d relations=%d",
			result.Workspace,
			result.Sample,
			result.UModel.Imported,
			result.UModel.Skipped,
			result.EntityCount,
			result.RelationCount,
		)
	}
	log.Printf("umodel-server listening on %s", *addr)
	if *uiDir != "" {
		log.Printf("serving web UI from %s", *uiDir)
	}
	log.Printf("built-in MCP enabled at /mcp/{workspace}")
	server := &http.Server{
		Addr:              *addr,
		Handler:           mountMCP(ctx, app, app.HandlerWithUI(*uiDir)),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       60 * time.Second,
		WriteTimeout:      120 * time.Second,
		IdleTimeout:       120 * time.Second,
		MaxHeaderBytes:    1 << 20, // 1 MiB
	}
	if err := server.ListenAndServe(); err != nil {
		log.Fatal(err)
	}
}

// mountMCP wraps the base handler and routes /mcp/{workspace} requests to the
// built-in MCP handler, so a single umodel-server process serves MCP for any
// workspace via path routing.
func mountMCP(ctx context.Context, app *bootstrap.App, base http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasPrefix(r.URL.Path, "/mcp") {
			base.ServeHTTP(w, r)
			return
		}

		// Extract workspace from /mcp/{workspace} or /mcp/{workspace}/...
		rest := strings.TrimPrefix(r.URL.Path, "/mcp")
		rest = strings.TrimPrefix(rest, "/")
		parts := strings.SplitN(rest, "/", 2)
		workspace := parts[0]
		if workspace == "" {
			http.Error(w, "workspace is required: /mcp/{workspace}", http.StatusBadRequest)
			return
		}

		// Create MCP handler for this workspace.
		mcpHandler := mcp.StreamableHTTPHandler(ctx, app, workspace)
		mcpHandler(w, r)
	})
}

func resolveProviderForQuickStart(provider string, quickStart bool, graphstoreExplicit bool) string {
	if quickStart && !graphstoreExplicit {
		return graphstore.ProviderTypeMemory
	}
	return provider
}

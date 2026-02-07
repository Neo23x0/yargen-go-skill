package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/Neo23x0/yarGen-go/internal/database"
	"github.com/Neo23x0/yarGen-go/internal/scanner"
)

var version = "0.1.0"

func main() {
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	switch os.Args[1] {
	case "update":
		cmdUpdate()
	case "create":
		cmdCreate()
	case "append":
		cmdAppend()
	case "inspect":
		cmdInspect()
	case "merge":
		cmdMerge()
	case "list":
		cmdList()
	case "submit":
		cmdSubmit()
	case "version":
		fmt.Printf("yargen-util version %s\n", version)
	case "help", "-h", "--help":
		printUsage()
	default:
		fmt.Fprintf(os.Stderr, "Unknown command: %s\n", os.Args[1])
		printUsage()
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Println("yargen-util - Database management utility for yarGen")
	fmt.Println()
	fmt.Println("Commands:")
	fmt.Println("  update              Download pre-built databases from GitHub")
	fmt.Println("  create              Create new database from goodware directory")
	fmt.Println("  append              Append to existing database")
	fmt.Println("  inspect <db-file>   Show database statistics")
	fmt.Println("  merge               Merge multiple databases")
	fmt.Println("  list                List all databases")
	fmt.Println("  submit <sample>     Submit sample to yarGen server and get rules")
	fmt.Println("  version             Show version")
	fmt.Println("  help                Show this help")
	fmt.Println()
	fmt.Println("Use 'yargen-util <command> -h' for more information about a command.")
}

// cmdSubmit submits a sample to the yarGen server and returns generated rules
func cmdSubmit() {
	fs := flag.NewFlagSet("submit", flag.ExitOnError)
	server := fs.String("server", "http://127.0.0.1:8080", "yarGen server URL")
	author := fs.String("a", "yarGen", "Author name")
	reference := fs.String("r", "", "Reference")
	showScores := fs.Bool("score", false, "Show scores as comments")
	noOpcodes := fs.Bool("no-opcodes", false, "Disable opcode analysis")
	output := fs.String("o", "", "Output file (default: stdout)")
	maxWait := fs.Int("wait", 600, "Maximum wait time in seconds")
	verbose := fs.Bool("v", false, "Verbose output")
	
	if err := fs.Parse(os.Args[2:]); err != nil {
		fmt.Fprintf(os.Stderr, "[E] Failed to parse flags: %v\n", err)
		fs.Usage()
		os.Exit(1)
	}

	if fs.NArg() < 1 {
		fmt.Fprintln(os.Stderr, "[E] Sample file required")
		fs.Usage()
		os.Exit(1)
	}

	samplePath := fs.Arg(0)
	
	// Check file exists
	if _, err := os.Stat(samplePath); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "[E] File not found: %s\n", samplePath)
		os.Exit(1)
	}

	// Check server health
	if *verbose {
		fmt.Printf("[*] Checking server at %s ...\n", *server)
	}
	
	if _, err := http.Get(*server + "/api/health"); err != nil {
		fmt.Fprintf(os.Stderr, "[E] yarGen server not running at %s\n", *server)
		fmt.Fprintln(os.Stderr, "    Start with: yargen serve")
		os.Exit(1)
	}

	fileName := filepath.Base(samplePath)
	
	if *verbose {
		fmt.Printf("[+] Submitting: %s\n", fileName)
	}

	// Upload file
	jobID, err := uploadFile(*server, samplePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[E] Upload failed: %v\n", err)
		os.Exit(1)
	}

	if *verbose {
		fmt.Printf("[+] Job ID: %s\n", jobID)
		fmt.Println("[*] Starting rule generation...")
	}

	// Start generation
	if err := startGeneration(*server, jobID, *author, *reference, *showScores, *noOpcodes); err != nil {
		fmt.Fprintf(os.Stderr, "[E] Failed to start generation: %v\n", err)
		os.Exit(1)
	}

	// Wait for completion
	if *verbose {
		fmt.Printf("[*] Waiting for generation (max %ds)...\n", *maxWait)
	}

	rules, err := waitForRules(*server, jobID, *maxWait, *verbose)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[E] %v\n", err)
		os.Exit(1)
	}

	// Output rules
	if *output != "" {
		if err := os.WriteFile(*output, []byte(rules), 0644); err != nil {
			fmt.Fprintf(os.Stderr, "[E] Failed to write output: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("[+] Rules saved to: %s\n", *output)
	} else {
		fmt.Println(rules)
	}
}

func uploadFile(server, filePath string) (string, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return "", err
	}
	defer file.Close()

	var buf bytes.Buffer
	writer := multipart.NewWriter(&buf)
	part, err := writer.CreateFormFile("file", filepath.Base(filePath))
	if err != nil {
		return "", err
	}
	
	if _, err := io.Copy(part, file); err != nil {
		return "", err
	}
	writer.Close()

	resp, err := http.Post(server+"/api/upload", writer.FormDataContentType(), &buf)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("upload failed: %s", resp.Status)
	}

	var result struct {
		ID string `json:"id"`
	}
	
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", err
	}
	
	if result.ID == "" {
		return "", fmt.Errorf("no job ID received")
	}
	
	return result.ID, nil
}

func startGeneration(server, jobID, author, reference string, showScores, noOpcodes bool) error {
	req := struct {
		JobID          string `json:"job_id"`
		Author         string `json:"author"`
		Reference      string `json:"reference,omitempty"`
		ShowScores     bool   `json:"show_scores"`
		ExcludeOpcodes bool   `json:"exclude_opcodes"`
	}{
		JobID:          jobID,
		Author:         author,
		Reference:      reference,
		ShowScores:     showScores,
		ExcludeOpcodes: noOpcodes,
	}

	body, err := json.Marshal(req)
	if err != nil {
		return err
	}

	resp, err := http.Post(server+"/api/generate", "application/json", bytes.NewReader(body))
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("generation failed: %s", resp.Status)
	}

	return nil
}

func waitForRules(server, jobID string, maxWait int, verbose bool) (string, error) {
	start := time.Now()
	lastStatus := ""
	
	for time.Since(start).Seconds() < float64(maxWait) {
		resp, err := http.Get(server + "/api/jobs/" + jobID)
		if err != nil {
			return "", err
		}

		var job struct {
			Status string `json:"status"`
			Error  string `json:"error"`
		}
		
		if err := json.NewDecoder(resp.Body).Decode(&job); err != nil {
			resp.Body.Close()
			return "", err
		}
		resp.Body.Close()

		if job.Status != lastStatus {
			lastStatus = job.Status
			if verbose {
				fmt.Printf("    Status: %s\n", job.Status)
			}
		}

		switch job.Status {
		case "completed":
			// Get rules
			rulesResp, err := http.Get(server + "/api/rules/" + jobID)
			if err != nil {
				return "", err
			}
			defer rulesResp.Body.Close()
			
			rules, err := io.ReadAll(rulesResp.Body)
			if err != nil {
				return "", err
			}
			return string(rules), nil
			
		case "failed":
			if job.Error != "" {
				return "", fmt.Errorf("generation failed: %s", job.Error)
			}
			return "", fmt.Errorf("generation failed")
		}

		time.Sleep(3 * time.Second)
	}
	
	return "", fmt.Errorf("timeout after %d seconds (job: %s)", maxWait, jobID)
}

// [Rest of the original main.go functions...]
// cmdUpdate, cmdCreate, cmdAppend, cmdInspect, cmdMerge, cmdList

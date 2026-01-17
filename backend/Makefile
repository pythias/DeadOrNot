# Makefile for DeadOrNot Backend

# 变量定义
APP_NAME := deadornot-backend
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_TIME := $(shell date -u '+%Y-%m-%d_%H:%M:%S')
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GO_VERSION := $(shell go version | awk '{print $$3}')

# 构建目录
BUILD_DIR := bin
DIST_DIR := dist

# Go 构建参数
LDFLAGS := -X main.Version=$(VERSION) \
           -X main.BuildTime=$(BUILD_TIME) \
           -X main.GitCommit=$(GIT_COMMIT) \
           -s -w

# 默认目标
.PHONY: all
all: build

# 编译 Linux amd64 二进制文件（用于生产环境）
.PHONY: build
build:
	@echo "Building $(APP_NAME) for Linux amd64..."
	@mkdir -p $(BUILD_DIR)
	@GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build \
		-ldflags "$(LDFLAGS)" \
		-o $(BUILD_DIR)/$(APP_NAME) \
		./main.go
	@echo "Build complete: $(BUILD_DIR)/$(APP_NAME)"
	@ls -lh $(BUILD_DIR)/$(APP_NAME)

# 本地编译（当前平台）
.PHONY: build-local
build-local:
	@echo "Building $(APP_NAME) for local platform..."
	@mkdir -p $(BUILD_DIR)
	@go build \
		-ldflags "$(LDFLAGS)" \
		-o $(BUILD_DIR)/$(APP_NAME) \
		./main.go
	@echo "Build complete: $(BUILD_DIR)/$(APP_NAME)"

# 运行应用（本地开发）
.PHONY: run
run:
	@echo "Running $(APP_NAME)..."
	@go run ./main.go

# 运行测试
.PHONY: test
test:
	@echo "Running tests..."
	@go test -v ./...

# 运行测试并生成覆盖率报告
.PHONY: test-coverage
test-coverage:
	@echo "Running tests with coverage..."
	@go test -v -coverprofile=coverage.out ./...
	@go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

# 下载依赖
.PHONY: deps
deps:
	@echo "Downloading dependencies..."
	@go mod download
	@go mod tidy

# 更新依赖
.PHONY: deps-update
deps-update:
	@echo "Updating dependencies..."
	@go get -u ./...
	@go mod tidy

# 代码格式化
.PHONY: fmt
fmt:
	@echo "Formatting code..."
	@go fmt ./...

# 代码检查（需要安装 golangci-lint）
.PHONY: lint
lint:
	@echo "Linting code..."
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run ./...; \
	else \
		echo "golangci-lint not found, skipping..."; \
		echo "Install with: go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest"; \
	fi

# 清理编译产物
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@rm -rf $(DIST_DIR)
	@rm -f coverage.out coverage.html
	@echo "Clean complete"

# 创建发布包
.PHONY: dist
dist: build
	@echo "Creating distribution package..."
	@mkdir -p $(DIST_DIR)
	@cp $(BUILD_DIR)/$(APP_NAME) $(DIST_DIR)/
	@cp -r deploy $(DIST_DIR)/ 2>/dev/null || true
	@echo "Distribution package created in $(DIST_DIR)/"

# 显示版本信息
.PHONY: version
version:
	@echo "Application: $(APP_NAME)"
	@echo "Version: $(VERSION)"
	@echo "Build Time: $(BUILD_TIME)"
	@echo "Git Commit: $(GIT_COMMIT)"
	@echo "Go Version: $(GO_VERSION)"

# 帮助信息
.PHONY: help
help:
	@echo "DeadOrNot Backend Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  make build          - Build for Linux amd64 (production)"
	@echo "  make build-local    - Build for local platform"
	@echo "  make run            - Run the application locally"
	@echo "  make test           - Run tests"
	@echo "  make test-coverage  - Run tests with coverage report"
	@echo "  make deps           - Download dependencies"
	@echo "  make deps-update    - Update dependencies"
	@echo "  make fmt            - Format code"
	@echo "  make lint           - Lint code (requires golangci-lint)"
	@echo "  make clean          - Clean build artifacts"
	@echo "  make dist           - Create distribution package"
	@echo "  make version        - Show version information"
	@echo "  make help           - Show this help message"

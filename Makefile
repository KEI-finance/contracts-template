# Makefile for deploying to multiple chains and environments

# Environment variables
# Source .env file globally if it exists
ifneq (,$(wildcard .env))
    include .env
    export
endif

ENV ?= develop
CHAIN ?= sepolia
ETHERSCAN_API_KEY ?= ""
BLAST_API_KEY ?= ""

# Decode secrets file if it exists
ifneq (,$(wildcard secrets/secrets.$(ENV).env))
    $(shell (sops -d secrets/secrets.$(ENV).env > .env.secrets 2>/dev/null) || (echo "Proceeding without secrets file" >&2))
    -include .env.secrets
    export
    $(shell rm -f .env.secrets)
endif

# Phony targets
.PHONY: deploy deploy-resume typechain typechain-clean typechain-v5 typechain-v6 prepublish setup help test print-env sync compile forge-clean compile-clean clean soldeer-publish

define set_etherscan_api_key
    $(eval ETHERSCAN_API_KEY := $(shell \
        if [ "$(CHAIN)" = "arbitrum" ] || [ "$(CHAIN)" = "arbitrum_sepolia" ]; then \
            echo "$(ARB_ETHERSCAN_API_KEY)"; \
        elif [ "$(CHAIN)" = "polygon" ] || [ "$(CHAIN)" = "polygon_sepolia" ]; then \
            echo "$(POLYGON_ETHERSCAN_API_KEY)"; \
        elif [ "$(CHAIN)" = "bsc" ]; then \
            echo "$(BSC_ETHERSCAN_API_KEY)"; \
        else \
            echo "$(ETHERSCAN_API_KEY)"; \
        fi \
    ))
endef

compile:
	@echo "Compiling contracts..."
	@npx tsc >> /dev/null || true

# Deploy to selected chain and environment
deploy:
	@echo "Deploying to $(CHAIN) in $(ENV) environment..."
	$(call set_etherscan_api_key)
	forge script script/Deploy.s.sol:DeployScript --broadcast --verify -vvvv --rpc-url $(CHAIN) --etherscan-api-key $(ETHERSCAN_API_KEY) --private-key $(PRIVATE_KEY) || true
	$(MAKE) deploy-tag

# Resume deployment on selected chain and environment
deploy-resume:
	@echo "Resuming deployment on $(CHAIN) in $(ENV) environment..."
	$(call set_etherscan_api_key)
	forge script script/Deploy.s.sol:DeployScript --broadcast --verify --resume -vvvv --rpc-url $(CHAIN) --etherscan-api-key $(ETHERSCAN_API_KEY) --private-key $(PRIVATE_KEY) || true
	$(MAKE) deploy-tag

deploy-tag:
	@echo "Tagging deployment to $(ENV) environment"
	@npx forge-utils append-meta --meta.env $(ENV) --new-files
	@git reset
	@npx forge-utils deployments
	@git add deployments.json broadcast > /dev/null || true
	@git commit -m "🚀🔥 DEPLOYED: $(CHAIN) network, $(ENV) environment 🌍💥"

compile-clean:
	@echo "Cleaning compiled utils..."
	@rm -f ./utils/**/*.js 2>/dev/null || true

# Clean TypeChain artifacts
typechain-clean:
	@echo "Cleaning TypeChain artifacts..."
	@rm -rf typechain

# Generate TypeChain bindings for ethers-v6
typechain-v6:
	@echo "Generating TypeChain bindings for ethers-v6..."
	@npx typechain --target ethers-v6 --out-dir typechain/ethers-v6 "./out/*.sol/*.json" --show-stack-traces >> /dev/null || true

# Generate TypeChain bindings for ethers-v5
typechain-v5:
	@echo "Generating TypeChain bindings for ethers-v5..."
	@npx typechain --target ethers-v5 --out-dir typechain/ethers-v5 "./out/*.sol/*.json" --show-stack-traces >> /dev/null || true

clean-typechain-bytecode:
	@echo "Cleaning TypeChain bytecode..."
	@npx forge-utils clean-typechain-bytecode

# Generate all TypeChain bindings
typechain: typechain-clean typechain-v6 typechain-v5 clean-typechain-bytecode

# Prepare for publishing
setup:
	@echo "Setting up the project..."

	@$(MAKE) clean
	@pnpm install
	@forge clean
	@forge install
	@forge soldeer install --clean
	@forge build --skip script test
	@$(MAKE) typechain
	@$(MAKE) compile
	@npx forge-utils deployments
	@git add deployments.json > /dev/null || true


forge-clean:
	@echo "Cleaning forge build..."
	@forge clean

# Clean build artifacts
clean:
	@$(MAKE) forge-clean >> /dev/null || true
	@$(MAKE) compile-clean >> /dev/null || true
	@$(MAKE) typechain-clean >> /dev/null || true

test:
	@echo "Running tests..."
	@forge test -vvv

# Print environment variables
print-env:
	@echo "Current environment variables:"
	@echo "ENV: $(ENV)"
	@echo "CHAIN: $(CHAIN)"

# Sync with template/master
sync:
	@echo "Syncing with template/master..."
	@echo "Checking if template origin exists..."
	@if ! git remote | grep -q '^template$$'; then \
		echo "Adding template origin..."; \
		git remote add template https://github.com/kei-finance/contracts-template.git; \
	else \
		echo "Template origin already exists."; \
	fi
	git fetch template master
	git merge --no-edit template/master --allow-unrelated-histories

sync-foundry:
	foundryup -v nightly-d14a7b44fc439407d761fccc4c1637216554bbb6

soldeer-publish:
	@cp package.json ./src/package.json && \
	cp README.md ./src/README.md && \
	VERSION=$$(node -p "require('./src/package.json').version"); \
	PACKAGE=$$(node -p "require('./src/package.json').name.replace(/[\.\-\/]/g, '-')"); \
	if forge soldeer push $$PACKAGE~$$VERSION src/; then \
		echo "Successfully published $$PACKAGE version $$VERSION"; \
	else \
		echo "Failed to publish $$PACKAGE version $$VERSION"; \
	fi; \
	rm ./src/package.json ./src/README.md;

# Help target
help:
	@echo "Available targets:"
	@echo "  deploy         - Deploy contracts to selected chain and environment"
	@echo "  deploy-resume  - Resume deployment on selected chain and environment"
	@echo "  typechain      - Generate all TypeChain bindings"
	@echo "  typechain-clean - Clean TypeChain artifacts"
	@echo "  typechain-v5   - Generate TypeChain bindings for ethers-v5"
	@echo "  typechain-v6   - Generate TypeChain bindings for ethers-v6"
	@echo "  clean          - Clean build artifacts"
	@echo "  setup          - Setup the project"
	@echo "  forge-clean    - Clean forge build"
	@echo "  compile-clean  - Clean compiled utils"
	@echo "  compile        - Compile contracts"
	@echo "  test           - Run tests"
	@echo "  soldeer-publish - Publish to Soldeer"
	@echo "  print-env      - Print current environment variables"
	@echo "  sync           - Sync with template/master"
	@echo "  help           - Show this help message"
	@echo ""
	@echo "Usage:"
	@echo "  make [target] ENV=[develop|staging|production] CHAIN=[sepolia|mainnet|goerli]"
	@echo "  Example: make deploy ENV=staging CHAIN=sepolia"

# Default target
.DEFAULT_GOAL := setup

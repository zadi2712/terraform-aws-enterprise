# VPC Endpoints Module - Tests

This directory contains tests for the VPC Endpoints module using Terraform's native testing framework.

## Prerequisites

- Terraform >= 1.6.0 (for native testing support)
- AWS credentials (for integration tests)
- Make (optional, for simplified commands)

## Test Structure

```
tests/
├── README.md           # This file
├── basic.tftest.hcl    # Basic functionality tests
└── ...                 # Additional test files
```

## Running Tests

### Option 1: Using Terraform CLI

```bash
# Run all tests
terraform test

# Run specific test file
terraform test -filter=tests/basic.tftest.hcl

# Run with verbose output
terraform test -verbose
```

### Option 2: Using Make

```bash
# From module root directory
make test
```

## Test Types

### 1. Unit Tests (basic.tftest.hcl)

Tests basic module functionality without creating real resources:
- Basic endpoint configuration
- Gateway endpoint creation
- Custom security group configuration
- Multiple endpoints handling

### 2. Integration Tests (Coming Soon)

Tests with actual AWS resources:
- Real VPC and subnet creation
- Endpoint connectivity validation
- DNS resolution testing
- Cost estimation validation

## Writing New Tests

Create a new `.tftest.hcl` file in this directory:

```hcl
# Example test structure
run "test_name" {
  command = plan  # or apply

  variables {
    # Test-specific variables
  }

  assert {
    condition     = # condition to check
    error_message = "Error message if assertion fails"
  }
}
```

## Test Best Practices

1. **Use descriptive names**: Name tests clearly to indicate what they test
2. **Test one thing**: Each test should verify a single behavior
3. **Include assertions**: Always validate expected outcomes
4. **Use plan for unit tests**: Use `command = plan` for fast feedback
5. **Use apply sparingly**: Only use `command = apply` for integration tests
6. **Clean up resources**: Ensure integration tests destroy resources

## Continuous Integration

These tests can be integrated into CI/CD pipelines:

```yaml
# GitHub Actions example
- name: Run Terraform tests
  run: |
    cd modules/vpc-endpoints
    terraform init
    terraform test
```

## Troubleshooting

### Tests fail with "Error: Invalid provider configuration"

Ensure AWS credentials are configured or use mock provider settings.

### Tests timeout

Check network connectivity and AWS API limits.

### Assertion failures

Review the error message and validate the test conditions match expected behavior.

## References

- [Terraform Testing](https://developer.hashicorp.com/terraform/language/tests)
- [Writing Tests](https://developer.hashicorp.com/terraform/language/tests/writing-tests)
- [Test Assertions](https://developer.hashicorp.com/terraform/language/tests/assertions)

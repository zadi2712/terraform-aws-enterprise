# Changelog

All notable changes to the VPC Endpoints module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-12

### Added
- Initial release of VPC Endpoints module
- Support for Interface VPC Endpoints (PrivateLink)
- Support for Gateway VPC Endpoints (S3, DynamoDB)
- Automatic security group creation with configurable rules
- Private DNS resolution support
- Multi-AZ deployment capability
- Custom IAM policy support for endpoints
- Comprehensive input validation
- Detailed outputs for all endpoint types
- Support for 40+ AWS services via Interface endpoints
- Gateway endpoint route table integration
- Custom timeouts for endpoint operations

### Documentation
- Comprehensive README with architecture diagrams
- Usage examples (basic, complete, advanced)
- Cost optimization strategies
- Security best practices
- Monitoring and troubleshooting guides
- Testing procedures
- Migration guide from NAT Gateway
- Compliance considerations (PCI-DSS, HIPAA)

### Examples
- Basic example: Minimal configuration
- Complete example: Full enterprise setup
- Advanced example: Custom policies and security groups

## [Unreleased]

### Planned
- Terraform test framework integration
- Additional service endpoint examples
- Cost calculator script
- Automated compliance checks
- Enhanced monitoring dashboards
- Terraform Cloud/Enterprise integration examples

---

## Version History

### Version Numbering
- **MAJOR**: Incompatible API changes
- **MINOR**: New functionality in a backwards compatible manner
- **PATCH**: Backwards compatible bug fixes

### Support Policy
- Latest version: Full support
- Previous minor version: Security fixes only
- Older versions: Community support only

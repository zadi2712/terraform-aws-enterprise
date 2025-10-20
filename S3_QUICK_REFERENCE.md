# S3 Quick Reference

## 🚀 Quick Start

```bash
# S3 buckets created automatically in storage layer
cd layers/storage/environments/dev
terraform apply

# List buckets
aws s3 ls

# Upload file
aws s3 cp file.txt s3://mybucket/

# Download file
aws s3 cp s3://mybucket/file.txt ./
```

---

## 📋 Common Commands

```bash
# List objects
aws s3 ls s3://mybucket/

# Sync directory
aws s3 sync ./local/ s3://mybucket/remote/

# Copy recursively
aws s3 cp ./local/ s3://mybucket/ --recursive

# Delete object
aws s3 rm s3://mybucket/file.txt

# Get object metadata
aws s3api head-object --bucket mybucket --key file.txt

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket mybucket \
  --versioning-configuration Status=Enabled

# List versions
aws s3api list-object-versions --bucket mybucket
```

---

## 🎯 Storage Classes

| Class | Retrieval | Price/GB | Use |
|-------|-----------|----------|-----|
| STANDARD | Immediate | $0.023 | Frequent |
| STANDARD_IA | Immediate | $0.0125 | Infrequent |
| GLACIER_IR | Immediate | $0.004 | Archive |
| GLACIER | Hours | $0.004 | Long-term |
| DEEP_ARCHIVE | 12h | $0.00099 | Compliance |

---

## 💰 Cost Optimization

```hcl
# Use lifecycle rules
transitions = [
  { days = 30, storage_class = "STANDARD_IA" }   # 50% savings
  { days = 90, storage_class = "GLACIER" }       # 83% savings
]

# Use Intelligent Tiering
# Automatically moves data

# Use S3 Bucket Key
bucket_key_enabled = true  # 99% KMS cost reduction
```

---

## 📚 Resources

- [S3 Module README](modules/s3/README.md)
- [S3 Deployment Guide](S3_DEPLOYMENT_GUIDE.md)

**S3 Quick Reference v2.0**


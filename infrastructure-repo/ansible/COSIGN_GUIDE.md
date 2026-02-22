# Cosign Image Signature Verification - Quick Guide

## Overview

Cosign signature verification is now enabled in your Kyverno configuration. All container images deployed to the `dev`, `staging`, and `prod` namespaces must be cryptographically signed.

## Prerequisites

### 1. Generate Cosign Key Pair (if not done already)

```bash
# Generate keypair
cosign generate-key-pair

# This creates:
# - cosign.key (private key - keep secure!)
# - cosign.pub (public key - share this)
```

### 2. Export Public Key

```bash
export COSIGN_PUBLIC_KEY="$(cat cosign.pub)"
```

## Signing Images

### Sign an Image After Building

```bash
# After building and pushing to ECR
cosign sign --key cosign.key <your-ecr-url>/<image>:<tag>

# Example:
cosign sign --key cosign.key \
  123456789.dkr.ecr.us-east-1.amazonaws.com/my-app:v1.0.0
```

### Integrate with CI/CD Pipeline

Add this to your Azure Pipeline after the image push step:

```yaml
- task: Bash@3
  displayName: 'Sign Container Image with Cosign'
  inputs:
    targetType: 'inline'
    script: |
      # Install Cosign
      curl -LO https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64
      chmod +x cosign-linux-amd64
      sudo mv cosign-linux-amd64 /usr/local/bin/cosign
      
      # Sign image
      echo "$(COSIGN_PRIVATE_KEY)" > cosign.key
      cosign sign --key cosign.key \
        $(ECR_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
```

## Verification

### Verify Signature Manually

```bash
# Verify an image signature
cosign verify --key cosign.pub <your-ecr-url>/<image>:<tag>

# Example:
cosign verify --key cosign.pub \
  123456789.dkr.ecr.us-east-1.amazonaws.com/my-app:v1.0.0
```

### Test in Kubernetes

```bash
# This should SUCCEED (signed image)
kubectl run test-signed \
  --image=<your-signed-ecr-image>:tag -n dev \
  --requests=cpu=100m,memory=128Mi \
  --limits=cpu=200m,memory=256Mi

# This should FAIL (unsigned image)
kubectl run test-unsigned \
  --image=<your-unsigned-ecr-image>:tag -n dev \
  --requests=cpu=100m,memory=128Mi \
  --limits=cpu=200m,memory=256Mi
# Error: image signature verification failed
```

## Policy Behavior

When Kyverno checks an image:

1. **Extract signature** from the image registry
2. **Verify signature** using the configured public key
3. **Allow** if signature is valid and matches the public key
4. **Block** if signature is invalid, missing, or doesn't match

## Troubleshooting

### Error: "no signatures found"

**Cause**: Image was not signed
**Solution**: Sign the image with Cosign before deploying

```bash
cosign sign --key cosign.key <image-url>
```

### Error: "invalid signature"

**Cause**: Image was signed with a different private key
**Solution**: Ensure you're using the same key pair

### Error: "failed to verify signature"

**Cause**: Public key mismatch
**Solution**: Verify the correct public key is exported:

```bash
echo $COSIGN_PUBLIC_KEY
# Should match the content of your cosign.pub file
```

## Security Best Practices

1. **Keep private key secure**
   - Store in Azure Key Vault or AWS Secrets Manager
   - Never commit to Git
   - Rotate regularly

2. **Use different keys per environment**
   - Dev: Less strict, for testing
   - Prod: Strict, audited access

3. **Enable keyless signing (optional)**
   - Use Sigstore's Fulcio for OIDC-based signing
   - No key management required

4. **Audit signature usage**
   ```bash
   kubectl get policyreports -n prod
   ```

## CI/CD Integration Example

Complete pipeline stage:

```yaml
- stage: BuildAndSign
  jobs:
    - job: BuildSignPush
      steps:
        # Build image
        - task: Docker@2
          inputs:
            command: build
            repository: $(IMAGE_NAME)
            tags: $(IMAGE_TAG)
        
        # Push to ECR
        - task: ECRPushImage@1
          inputs:
            imageSource: imagename
            sourceImageName: $(IMAGE_NAME)
            sourceImageTag: $(IMAGE_TAG)
        
        # Sign with Cosign
        - task: Bash@3
          displayName: 'Sign Image'
          inputs:
            targetType: 'inline'
            script: |
              cosign sign --key <(echo "$(COSIGN_PRIVATE_KEY)") \
                $(ECR_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
```

## Disabling Signature Verification (Not Recommended)

If you need to temporarily disable:

**In `group_vars/all.yml`:**
```yaml
kyverno:
  image_verification:
    require_signed_images: false  # Disable Cosign verification
```

Then re-run the Ansible playbook.

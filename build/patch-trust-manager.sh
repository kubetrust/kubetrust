#!/bin/bash
set -e

# Script to patch trust-manager chart by removing cert-manager dependencies
# Usage: ./patch-trust-manager.sh <version>
# Example: ./patch-trust-manager.sh 0.20.2

if [ -z "$1" ]; then
  echo "Error: Version parameter is required"
  echo "Usage: $0 <version>"
  echo "Example: $0 0.20.2"
  exit 1
fi

VERSION="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(dirname "$SCRIPT_DIR")/chart"
CHARTS_SUBDIR="$CHART_DIR/charts"
CHART_YAML="$CHART_DIR/Chart.yaml"

echo "==> Patching trust-manager chart version $VERSION"

# Step 1: Update Chart.yaml with the new version
echo "Step 1: Updating Chart.yaml with version $VERSION"
if ! grep -q "version: \"$VERSION\"" "$CHART_YAML"; then
  sed -i "s/version: \"[0-9.]*\"/version: \"$VERSION\"/" "$CHART_YAML"
  echo "  ✓ Updated Chart.yaml"
else
  echo "  ℹ Chart.yaml already has version $VERSION"
fi

# Step 2: Download the new chart via helm dependency update
echo "Step 2: Downloading trust-manager chart v$VERSION"
cd "$CHART_DIR"
helm dependency update
echo "  ✓ Downloaded trust-manager-${VERSION}.tgz"

# Step 3: Extract the chart
echo "Step 3: Extracting trust-manager chart"
cd "$CHARTS_SUBDIR"
if [ -d "trust-manager" ]; then
  rm -rf trust-manager
fi
tar -xzf "trust-manager-${VERSION}.tgz"
echo "  ✓ Extracted chart"

# Step 4: Apply patches

echo "Step 4: Applying patches"

# Patch 4a: Remove certificate.yaml (eliminates Certificate and Issuer CRDs)
if [ -f "trust-manager/templates/certificate.yaml" ]; then
  rm "trust-manager/templates/certificate.yaml"
  echo "  ✓ Removed certificate.yaml"
else
  echo "  ℹ certificate.yaml not found (may have been removed in this version)"
fi

# Patch 4b: Remove cert-manager annotation from webhook.yaml
WEBHOOK_FILE="trust-manager/templates/webhook.yaml"
if [ -f "$WEBHOOK_FILE" ]; then
  # Remove the cert-manager.io/inject-ca-from annotation section
  # This is a multi-line removal that handles the conditional annotation logic
  
  # Create a backup
  cp "$WEBHOOK_FILE" "${WEBHOOK_FILE}.bak"
  
  # Use perl for multi-line replacement (more reliable than sed for this case)
  perl -i -0pe 's/  \{\{- if or \(not \.Values\.app\.webhook\.tls\.helmCert\.enabled\) \.Values\.commonAnnotations \}\}\n  annotations:\n    \{\{- if not \.Values\.app\.webhook\.tls\.helmCert\.enabled \}\}\n    cert-manager\.io\/inject-ca-from: ".*?"\n    \{\{- end \}\}\n    \{\{- with \.Values\.commonAnnotations \}\}\n    \{\{- toYaml \. \| nindent 4 \}\}\n    \{\{- end \}\}\n  \{\{- end \}\}\n/  {{- with .Values.commonAnnotations }}\n  annotations:\n    {{- toYaml . | nindent 4 }}\n  {{- end }}\n/gs' "$WEBHOOK_FILE"
  
  # Remove the conditional caBundle section
  perl -i -0pe 's/\{\{ if \.Values\.app\.webhook\.tls\.helmCert\.enabled \}\}\n      caBundle: ".*?"\n\{\{ end \}\}\n/      caBundle: ""\n/gs' "$WEBHOOK_FILE"
  
  # Clean up backup
  rm "${WEBHOOK_FILE}.bak"
  
  echo "  ✓ Patched webhook.yaml (removed cert-manager annotation, added empty caBundle)"
else
  echo "  ✗ Error: webhook.yaml not found"
  exit 1
fi

# Step 5: Repackage the chart
echo "Step 5: Repackaging chart"
rm "trust-manager-${VERSION}.tgz" 2>/dev/null || true
helm package trust-manager
mv "trust-manager-v${VERSION}.tgz" "trust-manager-${VERSION}.tgz" 2>/dev/null || true
echo "  ✓ Created trust-manager-${VERSION}.tgz"

# Step 6: Clean up extracted directory
echo "Step 6: Cleaning up"
rm -rf trust-manager/
echo "  ✓ Removed extracted directory"

echo ""
echo "==> ✅ Successfully patched trust-manager v$VERSION"
echo ""
echo "Patches applied:"
echo "  1. Removed templates/certificate.yaml (Certificate and Issuer CRDs)"
echo "  2. Removed cert-manager.io/inject-ca-from annotation from ValidatingWebhookConfiguration"
echo "  3. Added empty caBundle field to webhook clientConfig"
echo ""
echo "The patched chart is ready at: $CHARTS_SUBDIR/trust-manager-${VERSION}.tgz"
echo ""
echo "Next steps:"
echo "  - Test the chart: helm upgrade --install kubetrust $CHART_DIR -n kubetrust-system -f values-test.yaml"
echo "  - Verify webhooks: kubectl get validatingwebhookconfiguration trust-manager -o yaml"

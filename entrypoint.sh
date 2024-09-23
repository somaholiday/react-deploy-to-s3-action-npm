#!/bin/sh

set -e

if [ -z "$AWS_S3_BUCKET" ]; then
  echo "AWS_S3_BUCKET is not set. Quitting."
  exit 1
fi

if [ -z "$AWS_ACCESS_KEY_ID" ]; then
  echo "AWS_ACCESS_KEY_ID is not set. Quitting."
  exit 1
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
  echo "AWS_SECRET_ACCESS_KEY is not set. Quitting."
  exit 1
fi

# Default to us-west-2 if AWS_REGION not set.
if [ -z "$AWS_REGION" ]; then
  AWS_REGION="us-west-2"
fi

# Override default AWS endpoint if user sets AWS_S3_ENDPOINT.
if [ -n "$AWS_S3_ENDPOINT" ]; then
  ENDPOINT_APPEND="--endpoint-url $AWS_S3_ENDPOINT"
fi

# Override default NODE_ENV (production) if set by user.
NODE_ENV_PREPEND="NODE_ENV=${NODE_ENV:-production}"
NODE_VITE_PREPEND="VITE_SPOTIFY_CLIENT_ID=${VITE_SPOTIFY_CLIENT_ID} VITE_SPOTIFY_REDIRECT_URL=${VITE_SPOTIFY_REDIRECT_URL}"

# Create a dedicated profile for this action to avoid conflicts
# with past/future actions.
aws configure --profile react-deploy-to-s3-action <<-EOF > /dev/null 2>&1
${AWS_ACCESS_KEY_ID}
${AWS_SECRET_ACCESS_KEY}
${AWS_REGION}
text
EOF

echo "Project directory:   ${PROJECT_DIR:-.}"
echo "Source directory:    ${SOURCE_DIR:-public}"

# - Install dependencies
# - Build react bundle
# - Sync using our dedicated profile and suppress verbose messages.
#   All other flags are optional via the `args:` directive.
cd ${PROJECT_DIR:-.}
npm install --include=dev && \
  npm run build && \
  aws s3 sync ${SOURCE_DIR:-public} s3://${AWS_S3_BUCKET}/${DEST_DIR} \
    --profile react-deploy-to-s3-action \
    --no-progress \
    ${ENDPOINT_APPEND} $*
cd -

# && sh -c "NODE_ENV=dev ${NODE_ENV_PREPEND} ${NODE_PUBLIC_URL_PREPEND} npm run deploy"
SUCCESS=$?

if [ $SUCCESS -eq 0 ]
then
  # Invalidate cloudfront distribution if user sets CLOUDFRONT_DISTRIBUTION_ID
  if [ -n "$CLOUDFRONT_DISTRIBUTION_ID" ]; then
    sh -c "aws cloudfront create-invalidation \
                          --distribution-id ${CLOUDFRONT_DISTRIBUTION_ID} \
                          --paths /\*"
  fi
fi

# Clear out credentials after we're done.
# We need to re-run `aws configure` with bogus input instead of
# deleting ~/.aws in case there are other credentials living there.
# https://forums.aws.amazon.com/thread.jspa?threadID=148833
aws configure --profile s3-sync-action <<-EOF > /dev/null 2>&1
null
null
null
text
EOF

if [ $SUCCESS -eq 0 ]
then
  echo "Deploy successful."
else
  echo "Failed to perform deploy!"
  exit 1
fi

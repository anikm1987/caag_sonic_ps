# AWS Bedrock Knowledge Base Setup Guide
## Creating a Knowledge Base with Website Crawling

This guide walks you through creating an AWS Bedrock Knowledge Base that uses the Web Crawler data source to index website content.

## Overview

AWS Bedrock Knowledge Base with Web Crawler allows you to:
- Crawl and index public or authorized websites
- Automatically convert web content into vector embeddings
- Enable RAG (Retrieval Augmented Generation) for your AI agents
- Keep content synchronized with automatic incremental updates

## Prerequisites

Before you begin, ensure you have:

1. **AWS Account** with appropriate permissions
2. **IAM User** (not root user) with Bedrock access
3. **Authorization** to crawl the target websites
4. **robots.txt compliance** - Ensure target sites allow crawling
5. **Model Access** - Enable embedding models in Bedrock console

### Required AWS Permissions

Your IAM user/role needs these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:CreateKnowledgeBase",
        "bedrock:CreateDataSource",
        "bedrock:StartIngestionJob",
        "bedrock:GetKnowledgeBase",
        "bedrock:ListKnowledgeBases",
        "bedrock:InvokeModel"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "aoss:CreateCollection",
        "aoss:CreateSecurityPolicy",
        "aoss:CreateAccessPolicy",
        "aoss:GetAccessPolicy",
        "aoss:UpdateAccessPolicy"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:AttachRolePolicy",
        "iam:PassRole"
      ],
      "Resource": "arn:aws:iam::*:role/AmazonBedrockExecutionRoleForKnowledgeBase*"
    }
  ]
}
```

## Step-by-Step Setup

### Step 1: Enable Model Access

1. Open the **Amazon Bedrock Console**: https://console.aws.amazon.com/bedrock
2. Navigate to **Model access** in the left sidebar
3. Click **Manage model access**
4. Enable the following models:
   - **Titan Embeddings G1 - Text** (for embeddings)
   - **Claude 3 Sonnet** or **Claude 3.5 Sonnet** (for the agent)
5. Click **Save changes**

Wait a few minutes for model access to be granted.

### Step 2: Create the Knowledge Base

1. In the Bedrock console, navigate to **Knowledge bases**
2. Click **Create knowledge base**
3. Configure basic settings:

   - **Name**: `my-website-kb` (or your preferred name)
   - **Description**: "Knowledge base for website content"
   - **IAM Role**: Select "Create and use a new service role"
   - **Tags** (optional): Add tags for organization
4. Click **Next**

### Step 3: Configure Web Crawler Data Source

1. In the **Data source** section, select **Web Crawler**
2. Configure the data source:
   - **Data source name**: `website-crawler`
   - **Description**: "Crawls website content"

#### Configure Source URLs

3. Add your website URLs to crawl:
   - Click **Add URL**
   - Enter the seed URL (e.g., `https://docs.aws.amazon.com/bedrock/`)
   - Add multiple URLs if needed

#### Configure Crawling Scope

4. Choose the **Crawling scope**:
   - **Default** (Recommended): Same host and path only
     - Example: `https://aws.amazon.com/bedrock/` → crawls `/bedrock/*` only
   - **Host only**: Same host, all paths
     - Example: `https://aws.amazon.com/bedrock/` → crawls all `aws.amazon.com`
   - **Subdomains**: Include all subdomains
     - Example: `https://aws.amazon.com/` → crawls `www.amazon.com`, `docs.aws.amazon.com`, etc.

⚠️ **Warning**: Be careful with broad scopes. Crawling large sites like Wikipedia can take hours and consume significant resources.

#### Configure Crawling Limits

5. Set **Rate limiting**:
   - **Max URLs per minute per host**: `300` (default)
   - Lower this if you want to be more respectful to the target server


6. Set **Maximum pages to crawl**: `10000` (or your desired limit, max 25,000)
   - If exceeded, the ingestion job will fail

#### Configure URL Filters (Optional)

7. Add **Inclusion patterns** (optional):
   - Use regex to include specific URLs
   - Example: `.*\/documentation\/.*` (only crawl documentation pages)

8. Add **Exclusion patterns** (optional):
   - Use regex to exclude specific URLs
   - Example: `.*\.pdf$` (exclude PDF files)
   - Example: `.*\/archive\/.*` (exclude archive pages)

**Note**: If a URL matches both inclusion and exclusion patterns, exclusion takes precedence.

#### Configure robots.txt Compliance

9. **User-Agent suffix** (optional):
   - Add a custom suffix to identify your crawler
   - Example: `my-company-crawler`
   - This helps with allowlisting in bot protection systems

The crawler will use the User-Agent: `bedrockbot-{UUID}` or `bedrockbot`

**robots.txt Example**:
```
User-agent: bedrockbot-UUID
Allow: /

User-agent: *
Disallow: /
```

10. Click **Next**

### Step 4: Configure Embeddings Model

1. Select an **Embeddings model**:
   - **Recommended**: `Titan Embeddings G1 - Text`
   - Alternative: `Cohere Embed English v3` or `Cohere Embed Multilingual v3`

2. Configure **Additional settings** (if available):
   - **Embeddings type**: `Float` (more accurate) or `Binary` (faster, less storage)
   - **Vector dimensions**: Higher = more accurate but more expensive


3. Click **Next**

### Step 5: Configure Vector Database

1. Choose **Quick create a new vector store** (Recommended for beginners)

2. Select a vector store:
   - **Amazon OpenSearch Serverless** (Recommended)
     - Fully managed, auto-scaling
     - Best for most use cases
   - **Amazon Aurora PostgreSQL Serverless**
     - Good for existing PostgreSQL users
   - **Amazon Neptune Analytics**
     - Best for graph-based queries
   - **Amazon S3 Vectors** (Preview)
     - Simplest option, S3-based storage

3. For OpenSearch Serverless:
   - Bedrock will automatically create:
     - Collection
     - Index with required fields
     - Security policies

4. **Encryption** (optional):
   - Choose AWS managed key or customer managed key (CMK)

5. Click **Next**

### Step 6: Review and Create

1. Review all configurations:
   - Knowledge base details
   - Data source settings
   - Embeddings model
   - Vector store

2. Click **Create knowledge base**

3. Wait for creation to complete (typically 2-5 minutes)
   - Status will change from "Creating" to "Active"

### Step 7: Sync Data Source

Once the knowledge base is created, you need to sync the data source to start crawling:

1. In the Knowledge base details page, find the **Data source** section
2. Select your web crawler data source
3. Click **Sync**

4. Monitor the sync progress:
   - **In Progress**: Crawling and indexing
   - **Completed**: Successfully indexed
   - **Failed**: Check CloudWatch logs for errors

**First sync can take several minutes to hours** depending on:
- Number of pages
- Page size
- Crawling rate limits
- Network conditions

### Step 8: Enable CloudWatch Logging (Recommended)

To monitor crawling status and troubleshoot issues:

1. Go to your Knowledge base settings
2. Navigate to **Logging** section
3. Enable **CloudWatch Logs**
4. Create or select a log group
5. Save changes

View logs to see:
- URLs being crawled
- URLs that failed to crawl
- robots.txt compliance issues
- Rate limiting information

## Using Your Knowledge Base

### Get Knowledge Base ID

1. In the Bedrock console, go to **Knowledge bases**
2. Click on your knowledge base
3. Copy the **Knowledge base ID** (format: `ABCDEFGHIJ`)


## Programmatic Setup with Boto3


For automation, you can create the knowledge base using Python and boto3:

```python
import boto3
import json
import time

# Initialize clients
bedrock_agent = boto3.client('bedrock-agent', region_name='us-east-1')
iam = boto3.client('iam')

# Step 1: Create IAM role for Knowledge Base
trust_policy = {
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Principal": {"Service": "bedrock.amazonaws.com"},
        "Action": "sts:AssumeRole"
    }]
}

role_name = "AmazonBedrockExecutionRoleForKnowledgeBase"

try:
    role_response = iam.create_role(
        RoleName=role_name,
        AssumeRolePolicyDocument=json.dumps(trust_policy),
        Description="Role for Bedrock Knowledge Base"
    )
    role_arn = role_response['Role']['Arn']
    
    # Attach required policies
    iam.attach_role_policy(
        RoleName=role_name,
        PolicyArn='arn:aws:iam::aws:policy/AmazonBedrockFullAccess'
    )
    
    # Wait for role to be available
    time.sleep(10)
    
except iam.exceptions.EntityAlreadyExistsException:
    role_arn = iam.get_role(RoleName=role_name)['Role']['Arn']

print(f"IAM Role ARN: {role_arn}")

# Step 2: Create Knowledge Base
kb_response = bedrock_agent.create_knowledge_base(
    name='my-website-kb',
    description='Knowledge base for website content',
    roleArn=role_arn,
    knowledgeBaseConfiguration={
        'type': 'VECTOR',
        'vectorKnowledgeBaseConfiguration': {
            'embeddingModelArn': 'arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v1'
        }
    },
    storageConfiguration={
        'type': 'OPENSEARCH_SERVERLESS',
        'opensearchServerlessConfiguration': {
            'collectionArn': 'arn:aws:aoss:us-east-1:ACCOUNT_ID:collection/COLLECTION_ID',
            'vectorIndexName': 'bedrock-knowledge-base-index',
            'fieldMapping': {
                'vectorField': 'bedrock-knowledge-base-default-vector',
                'textField': 'AMAZON_BEDROCK_TEXT_CHUNK',
                'metadataField': 'AMAZON_BEDROCK_METADATA'
            }
        }
    }
)

kb_id = kb_response['knowledgeBase']['knowledgeBaseId']
print(f"Knowledge Base ID: {kb_id}")

# Step 3: Create Web Crawler Data Source
ds_response = bedrock_agent.create_data_source(
    knowledgeBaseId=kb_id,
    name='website-crawler',
    description='Crawls website content',
    dataSourceConfiguration={
        'type': 'WEB',
        'webConfiguration': {
            'sourceConfiguration': {
                'urlConfiguration': {
                    'seedUrls': [
                        {'url': 'https://docs.aws.amazon.com/bedrock/'}
                    ]
                }
            },
            'crawlerConfiguration': {
                'crawlerLimits': {
                    'rateLimit': 300,
                    'maxPages': 10000
                },
                'scope': 'HOST_ONLY',
                'inclusionFilters': [],
                'exclusionFilters': ['.*\\.pdf$']
            }
        }
    }
)

data_source_id = ds_response['dataSource']['dataSourceId']
print(f"Data Source ID: {data_source_id}")

# Step 4: Start Ingestion Job
ingestion_response = bedrock_agent.start_ingestion_job(
    knowledgeBaseId=kb_id,
    dataSourceId=data_source_id
)

print(f"Ingestion Job ID: {ingestion_response['ingestionJob']['ingestionJobId']}")
print("Crawling started! Monitor progress in CloudWatch or the console.")
```

## Configuration Options Reference

### Crawling Scope Options


| Scope | Description | Example |
|-------|-------------|---------|
| `DEFAULT` | Same host and path | `https://aws.amazon.com/bedrock/` → only `/bedrock/*` |
| `HOST_ONLY` | Same host, all paths | `https://aws.amazon.com/bedrock/` → all `aws.amazon.com` |
| `SUBDOMAINS` | All subdomains | `https://aws.amazon.com/` → `docs.aws.amazon.com`, `www.amazon.com` |

### Supported File Types

The web crawler can index these file types:
- HTML pages (`.html`, `.htm`)
- PDF documents (`.pdf`)
- Microsoft Word (`.doc`, `.docx`)
- Microsoft PowerPoint (`.ppt`, `.pptx`)
- Text files (`.txt`)
- Markdown (`.md`)
- CSV files (`.csv`)

### Rate Limiting Best Practices

| Website Type | Recommended Rate | Max Pages |
|--------------|------------------|-----------|
| Small site (<100 pages) | 300/min | 1,000 |
| Medium site (100-1000 pages) | 200/min | 5,000 |
| Large site (>1000 pages) | 100/min | 10,000 |
| Very large site | 50/min | 25,000 |

## Maintenance and Updates

### Incremental Syncing

After the initial sync, subsequent syncs are incremental:
- New pages are added
- Modified pages are updated
- Deleted pages are removed

**Sync frequency recommendations**:
- **Daily updates**: Sync once per day
- **Weekly updates**: Sync once per week
- **On-demand**: Sync when content changes

### Manual Sync

```bash
aws bedrock-agent start-ingestion-job \
  --knowledge-base-id ABCDEFGHIJ \
  --data-source-id DATASOURCE_ID \
  --region us-east-1
```

### Automated Sync with EventBridge


Create a scheduled rule to sync automatically:

```python
import boto3

events = boto3.client('events')
lambda_client = boto3.client('lambda')

# Create EventBridge rule for daily sync
events.put_rule(
    Name='DailyKBSync',
    ScheduleExpression='cron(0 2 * * ? *)',  # 2 AM UTC daily
    State='ENABLED',
    Description='Daily sync for Knowledge Base'
)

# Add Lambda function as target (Lambda function not shown)
events.put_targets(
    Rule='DailyKBSync',
    Targets=[{
        'Id': '1',
        'Arn': 'arn:aws:lambda:us-east-1:ACCOUNT_ID:function:SyncKBFunction'
    }]
)
```

## Troubleshooting

### Common Issues

#### 1. "robots.txt disallows crawling"

**Problem**: The website's robots.txt blocks the crawler

**Solution**:
- Check `https://example.com/robots.txt`
- Contact website owner for permission
- Add custom User-Agent suffix and update robots.txt

#### 2. "Ingestion job failed"

**Problem**: Sync job fails during crawling

**Solutions**:
- Check CloudWatch logs for specific errors
- Reduce max pages limit
- Add exclusion filters for problematic URLs
- Verify network connectivity

#### 3. "Too many pages to crawl"

**Problem**: Exceeds 25,000 page limit

**Solutions**:
- Add more specific URL filters
- Use narrower crawling scope (DEFAULT instead of SUBDOMAINS)
- Split into multiple knowledge bases

#### 4. "Empty results from knowledge base"

**Problem**: Queries return no results

**Solutions**:
- Verify sync completed successfully
- Check that pages were actually crawled (CloudWatch logs)
- Ensure embeddings model is compatible
- Try lowering `min_score` threshold in queries


#### 5. "Rate limiting errors"

**Problem**: Target server blocks requests

**Solutions**:
- Reduce crawling rate (e.g., 50 URLs/min)
- Add delays between requests
- Contact website administrator

### Viewing Crawl Status

Check CloudWatch Logs for detailed information:

```bash
aws logs tail /aws/bedrock/knowledgebases/KNOWLEDGE_BASE_ID \
  --follow \
  --region us-east-1
```

Look for log entries like:
```
[INFO] Crawling URL: https://example.com/page1
[INFO] Successfully indexed: https://example.com/page1
[WARN] Skipped (robots.txt): https://example.com/blocked
[ERROR] Failed to fetch: https://example.com/error (404)
```

## Cost Considerations

### Pricing Components

1. **Embeddings Model**: Charged per 1,000 tokens
   - Titan Embeddings: ~$0.0001 per 1,000 tokens
   
2. **Vector Storage**: 
   - OpenSearch Serverless: ~$0.24/OCU-hour + storage
   - Aurora PostgreSQL: Based on ACU usage
   
3. **Data Transfer**: Standard AWS data transfer rates

4. **Bedrock API Calls**: Per request pricing

### Cost Optimization Tips

- Use exclusion filters to avoid indexing unnecessary content
- Set appropriate max pages limit
- Use binary embeddings instead of float (if accuracy allows)
- Schedule syncs during off-peak hours
- Monitor and delete unused knowledge bases

### Estimated Costs (Example)

For a 1,000-page website:
- Initial indexing: ~$2-5
- Monthly storage: ~$20-50
- Monthly queries (1000/day): ~$10-20

**Total**: ~$30-75/month

## Best Practices

### 1. Website Selection


✅ **Do**:
- Crawl your own websites or sites you have permission to crawl
- Respect robots.txt directives
- Use appropriate rate limits
- Start with narrow scope and expand gradually

❌ **Don't**:
- Crawl sites without authorization
- Ignore robots.txt
- Crawl extremely large sites (Wikipedia, etc.) without filters
- Use aggressive rate limits that could impact site performance

### 2. URL Filtering

✅ **Do**:
- Exclude archive/old content: `.*\/archive\/.*`
- Exclude media files: `.*\.(jpg|png|gif|mp4)$`
- Exclude admin pages: `.*\/admin\/.*`
- Include only relevant sections: `.*\/docs\/.*`

### 3. Monitoring

✅ **Do**:
- Enable CloudWatch logging
- Monitor ingestion job status
- Set up alerts for failed syncs
- Review crawl statistics regularly

### 4. Content Quality

✅ **Do**:
- Ensure crawled content is well-structured HTML
- Verify pages have meaningful text content
- Test with sample queries after initial sync
- Adjust chunking strategy if needed

## Security Considerations

### 1. IAM Permissions

- Use least-privilege IAM policies
- Separate roles for different environments
- Enable MFA for console access
- Regularly audit permissions

### 2. Data Encryption

- Use AWS KMS for encryption at rest
- Enable encryption in transit (HTTPS)
- Use customer-managed keys for sensitive data

### 3. Network Security

- Use VPC endpoints for private connectivity
- Implement security groups and NACLs
- Enable VPC Flow Logs for monitoring

### 4. Access Control

- Restrict knowledge base access to authorized users
- Use resource-based policies
- Enable CloudTrail for audit logging

## Next Steps

After setting up your knowledge base:

1. **Test thoroughly**: Query with various questions
2. **Monitor performance**: Check response quality and latency
3. **Iterate on filters**: Refine URL patterns based on results
4. **Set up automation**: Schedule regular syncs
5. **Integrate with agent**: Use the KB ID in your agent configuration

## Additional Resources


- [AWS Bedrock Knowledge Bases Documentation](https://docs.aws.amazon.com/bedrock/latest/userguide/knowledge-base.html)
- [Web Crawler Data Source](https://docs.aws.amazon.com/bedrock/latest/userguide/webcrawl-data-source-connector.html)
- [Knowledge Base Quotas](https://docs.aws.amazon.com/bedrock/latest/userguide/quotas.html)
- [Bedrock Pricing](https://aws.amazon.com/bedrock/pricing/)
- [robots.txt RFC 9309](https://www.rfc-editor.org/rfc/rfc9309.html)

## Quick Reference Commands

### Create Knowledge Base (CLI)
```bash
aws bedrock-agent create-knowledge-base \
  --name "my-website-kb" \
  --role-arn "arn:aws:iam::ACCOUNT_ID:role/BedrockKBRole" \
  --knowledge-base-configuration file://kb-config.json \
  --storage-configuration file://storage-config.json \
  --region us-east-1
```

### Create Data Source (CLI)
```bash
aws bedrock-agent create-data-source \
  --knowledge-base-id ABCDEFGHIJ \
  --name "website-crawler" \
  --data-source-configuration file://datasource-config.json \
  --region us-east-1
```

### Start Sync (CLI)
```bash
aws bedrock-agent start-ingestion-job \
  --knowledge-base-id ABCDEFGHIJ \
  --data-source-id DATASOURCE_ID \
  --region us-east-1
```

### Check Sync Status (CLI)
```bash
aws bedrock-agent get-ingestion-job \
  --knowledge-base-id ABCDEFGHIJ \
  --data-source-id DATASOURCE_ID \
  --ingestion-job-id JOB_ID \
  --region us-east-1
```

---

**Need Help?** 
- Check the troubleshooting section above
- Review CloudWatch logs for detailed error messages
- Consult AWS Bedrock documentation
- Contact AWS Support for complex issues

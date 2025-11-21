# Setup HTTPS for ALB
# Option 1: Self-signed certificate (for testing only)
# Option 2: ACM certificate with custom domain (production)

param([switch]$UseSelfSigned = $false)

$ALB_ARN = "arn:aws:elasticloadbalancing:us-east-1:171308902397:loadbalancer/app/course-reg-alb/7d13a6bcf5e0d9f7"
$TG_ARN = "arn:aws:elasticloadbalancing:us-east-1:171308902397:targetgroup/course-reg-tg/e0dfed577c96c70c"

if ($UseSelfSigned) {
    Write-Host "`n=== Self-Signed Certificate (Testing Only) ===" -ForegroundColor Yellow
    Write-Host "This is NOT recommended for production!" -ForegroundColor Red
    
    # Self-signed certs are not supported by ACM for ALB
    # You need to use ACM with a custom domain or AWS Certificate Manager
    Write-Host "`nALB requires ACM certificate. You have 2 options:" -ForegroundColor Cyan
    Write-Host "1. Register a domain and use ACM to issue certificate" -ForegroundColor Gray
    Write-Host "2. Use CloudFront with custom SSL certificate" -ForegroundColor Gray
    Write-Host "3. Keep using HTTP (current setup)" -ForegroundColor Gray
    exit
}

Write-Host "`n=== Setup HTTPS with ACM ===" -ForegroundColor Cyan

Write-Host "`nOption 1: Use existing domain" -ForegroundColor Yellow
Write-Host "If you have a domain (e.g., myapp.com):" -ForegroundColor Gray
Write-Host "1. Request certificate from ACM:" -ForegroundColor Gray
Write-Host "   aws acm request-certificate --domain-name api.myapp.com --validation-method DNS" -ForegroundColor DarkGray
Write-Host "2. Add DNS validation records to your domain" -ForegroundColor Gray
Write-Host "3. Wait for validation" -ForegroundColor Gray
Write-Host "4. Add HTTPS listener to ALB:" -ForegroundColor Gray
Write-Host "   aws elbv2 create-listener --load-balancer-arn <ALB_ARN> --protocol HTTPS --port 443 --certificates CertificateArn=<CERT_ARN> --default-actions Type=forward,TargetGroupArn=<TG_ARN>" -ForegroundColor DarkGray

Write-Host "`nOption 2: CloudFront with ALB origin (HTTPS to users, HTTP to ALB)" -ForegroundColor Yellow
Write-Host "CloudFront handles HTTPS with its default certificate" -ForegroundColor Gray
Write-Host "CloudFront -> HTTP -> ALB (internal AWS traffic, secure)" -ForegroundColor Gray

Write-Host "`nOption 3: Use S3 HTTP endpoint (current solution)" -ForegroundColor Green
Write-Host "Frontend: http://course-reg-frontend-8157.s3-website-us-east-1.amazonaws.com" -ForegroundColor Cyan
Write-Host "Backend: http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com" -ForegroundColor Cyan
Write-Host "No mixed content, no SSL needed, works immediately!" -ForegroundColor Green

Write-Host "`n=== Recommendation ===" -ForegroundColor Cyan
Write-Host "For demo/testing: Use S3 HTTP (Option 3)" -ForegroundColor Green
Write-Host "For production: Get a domain and use ACM certificate (Option 1)" -ForegroundColor Yellow

# create-useful-indexes.ps1
# Create practical GSI based on actual table schema
# Focused on real query patterns for the course registration system

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Create Useful DynamoDB Indexes" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$region = "us-east-1"
Write-Host "Region: $region" -ForegroundColor Yellow
Write-Host ""

# Function to check if GSI exists
function GSI-Exists {
    param(
        [string]$TableName,
        [string]$IndexName
    )
    
    try {
        $table = aws dynamodb describe-table --table-name $TableName --region $region 2>$null | ConvertFrom-Json
        $exists = $table.Table.GlobalSecondaryIndexes | Where-Object { $_.IndexName -eq $IndexName }
        return $null -ne $exists
    } catch {
        return $false
    }
}

Write-Host "Analyzing existing indexes..." -ForegroundColor Yellow
Write-Host ""

# Check CourseReg_Courses indexes
Write-Host "CourseReg_Courses table:" -ForegroundColor Cyan
$coursesTable = aws dynamodb describe-table --table-name CourseReg_Courses --region $region | ConvertFrom-Json

if ($coursesTable.Table.GlobalSecondaryIndexes) {
    foreach ($gsi in $coursesTable.Table.GlobalSecondaryIndexes) {
        $status = $gsi.IndexStatus
        $color = if ($status -eq "ACTIVE") { "Green" } else { "Yellow" }
        Write-Host "  ✓ $($gsi.IndexName) - Status: $status" -ForegroundColor $color
        
        # Show key schema
        $keys = $gsi.KeySchema | ForEach-Object { "$($_.AttributeName) ($($_.KeyType))" }
        Write-Host "    Keys: $($keys -join ', ')" -ForegroundColor Gray
    }
} else {
    Write-Host "  No GSI found" -ForegroundColor Yellow
}
Write-Host ""

# Check CourseReg_Enrollments indexes
Write-Host "CourseReg_Enrollments table:" -ForegroundColor Cyan
$enrollmentsTable = aws dynamodb describe-table --table-name CourseReg_Enrollments --region $region | ConvertFrom-Json

if ($enrollmentsTable.Table.GlobalSecondaryIndexes) {
    foreach ($gsi in $enrollmentsTable.Table.GlobalSecondaryIndexes) {
        $status = $gsi.IndexStatus
        $color = if ($status -eq "ACTIVE") { "Green" } else { "Yellow" }
        Write-Host "  ✓ $($gsi.IndexName) - Status: $status" -ForegroundColor $color
        
        $keys = $gsi.KeySchema | ForEach-Object { "$($_.AttributeName) ($($_.KeyType))" }
        Write-Host "    Keys: $($keys -join ', ')" -ForegroundColor Gray
    }
} else {
    Write-Host "  No GSI found" -ForegroundColor Yellow
}
Write-Host ""

# Recommendations for new indexes
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Index Recommendations" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Based on common query patterns:" -ForegroundColor Yellow
Write-Host ""

Write-Host "CourseReg_Courses:" -ForegroundColor Cyan
Write-Host "  ✓ semester-index (semester_id + course_id) - ALREADY EXISTS" -ForegroundColor Green
Write-Host "    Use case: List courses by semester" -ForegroundColor Gray
Write-Host "  ✓ department-index (department_id) - ALREADY EXISTS" -ForegroundColor Green
Write-Host "    Use case: List courses by department" -ForegroundColor Gray
Write-Host ""
Write-Host "  Suggested new indexes:" -ForegroundColor Yellow
Write-Host "  • teacher-index (teacher_id + course_code)" -ForegroundColor Cyan
Write-Host "    Use case: List all courses taught by a teacher" -ForegroundColor Gray
Write-Host "    Command:" -ForegroundColor Gray
Write-Host "      aws dynamodb update-table --table-name CourseReg_Courses --region $region ``" -ForegroundColor White
Write-Host "        --attribute-definitions AttributeName=teacher_id,AttributeType=S AttributeName=course_code,AttributeType=S ``" -ForegroundColor White
Write-Host "        --global-secondary-index-updates ""[{""""Create"""": {""""IndexName"""": """"teacher-index"""", """"KeySchema"""": [{""""AttributeName"""": """"teacher_id"""", """"KeyType"""": """"HASH""""}, {""""AttributeName"""": """"course_code"""", """"KeyType"""": """"RANGE""""}], """"Projection"""": {""""ProjectionType"""": """"ALL""""}, """"ProvisionedThroughput"""": {""""ReadCapacityUnits"""": 5, """"WriteCapacityUnits"""": 5}}}]""" -ForegroundColor White
Write-Host ""

Write-Host "CourseReg_Enrollments:" -ForegroundColor Cyan
Write-Host "  Suggested indexes:" -ForegroundColor Yellow
Write-Host "  • student-index (student_id + enrollment_date)" -ForegroundColor Cyan
Write-Host "    Use case: Get all enrollments for a student" -ForegroundColor Gray
Write-Host "    Command:" -ForegroundColor Gray
Write-Host "      aws dynamodb update-table --table-name CourseReg_Enrollments --region $region ``" -ForegroundColor White
Write-Host "        --attribute-definitions AttributeName=student_id,AttributeType=S AttributeName=enrollment_date,AttributeType=S ``" -ForegroundColor White
Write-Host "        --global-secondary-index-updates ""[{""""Create"""": {""""IndexName"""": """"student-index"""", """"KeySchema"""": [{""""AttributeName"""": """"student_id"""", """"KeyType"""": """"HASH""""}, {""""AttributeName"""": """"enrollment_date"""", """"KeyType"""": """"RANGE""""}], """"Projection"""": {""""ProjectionType"""": """"ALL""""}, """"ProvisionedThroughput"""": {""""ReadCapacityUnits"""": 10, """"WriteCapacityUnits"""": 5}}}]""" -ForegroundColor White
Write-Host ""
Write-Host "  • course-enrollments-index (course_id + enrollment_date)" -ForegroundColor Cyan
Write-Host "    Use case: Get all students enrolled in a course" -ForegroundColor Gray
Write-Host "    Command:" -ForegroundColor Gray
Write-Host "      aws dynamodb update-table --table-name CourseReg_Enrollments --region $region ``" -ForegroundColor White
Write-Host "        --attribute-definitions AttributeName=course_id,AttributeType=S AttributeName=enrollment_date,AttributeType=S ``" -ForegroundColor White
Write-Host "        --global-secondary-index-updates ""[{""""Create"""": {""""IndexName"""": """"course-enrollments-index"""", """"KeySchema"""": [{""""AttributeName"""": """"course_id"""", """"KeyType"""": """"HASH""""}, {""""AttributeName"""": """"enrollment_date"""", """"KeyType"""": """"RANGE""""}], """"Projection"""": {""""ProjectionType"""": """"ALL""""}, """"ProvisionedThroughput"""": {""""ReadCapacityUnits"""": 10, """"WriteCapacityUnits"""": 5}}}]""" -ForegroundColor White
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Current Status:" -ForegroundColor Yellow
Write-Host "  [OK] CourseReg_Courses has 2 GSI (semester, department)" -ForegroundColor Green
Write-Host "  [!] CourseReg_Enrollments has 0 GSI" -ForegroundColor Yellow
Write-Host ""
Write-Host "Recommended Actions:" -ForegroundColor Yellow
Write-Host "  1. Create student-index on Enrollments (high priority)" -ForegroundColor Cyan
Write-Host "  2. Create course-enrollments-index on Enrollments (high priority)" -ForegroundColor Cyan
Write-Host "  3. Create teacher-index on Courses (optional)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Would you like to create these indexes now? (y/n)" -ForegroundColor Yellow
$confirm = Read-Host

if ($confirm -eq 'y' -or $confirm -eq 'Y') {
    Write-Host ""
    Write-Host "Creating indexes..." -ForegroundColor Green
    Write-Host ""
    
    # Create student-index
    Write-Host "1. Creating student-index on CourseReg_Enrollments..." -ForegroundColor Cyan
    try {
        aws dynamodb update-table `
            --table-name CourseReg_Enrollments `
            --region $region `
            --attribute-definitions AttributeName=student_id,AttributeType=S AttributeName=enrollment_date,AttributeType=S `
            --global-secondary-index-updates '[{"Create": {"IndexName": "student-index", "KeySchema": [{"AttributeName": "student_id", "KeyType": "HASH"}, {"AttributeName": "enrollment_date", "KeyType": "RANGE"}], "Projection": {"ProjectionType": "ALL"}, "ProvisionedThroughput": {"ReadCapacityUnits": 10, "WriteCapacityUnits": 5}}}]' | Out-Null
        Write-Host "  ✓ student-index creation initiated" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Failed: $_" -ForegroundColor Red
    }
    
    Start-Sleep -Seconds 2
    
    # Create course-enrollments-index
    Write-Host "2. Creating course-enrollments-index on CourseReg_Enrollments..." -ForegroundColor Cyan
    try {
        aws dynamodb update-table `
            --table-name CourseReg_Enrollments `
            --region $region `
            --attribute-definitions AttributeName=course_id,AttributeType=S AttributeName=enrollment_date,AttributeType=S `
            --global-secondary-index-updates '[{"Create": {"IndexName": "course-enrollments-index", "KeySchema": [{"AttributeName": "course_id", "KeyType": "HASH"}, {"AttributeName": "enrollment_date", "KeyType": "RANGE"}], "Projection": {"ProjectionType": "ALL"}, "ProvisionedThroughput": {"ReadCapacityUnits": 10, "WriteCapacityUnits": 5}}}]' | Out-Null
        Write-Host "  ✓ course-enrollments-index creation initiated" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Failed: $_" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Indexes are being created. This may take 5-10 minutes." -ForegroundColor Yellow
    Write-Host "Check status with:" -ForegroundColor Gray
    Write-Host "  aws dynamodb describe-table --table-name CourseReg_Enrollments --region $region --query 'Table.GlobalSecondaryIndexes[*].[IndexName,IndexStatus]' --output table" -ForegroundColor White
    
} else {
    Write-Host ""
    Write-Host "Skipped index creation. Run the AWS CLI commands above manually when ready." -ForegroundColor Yellow
}

Write-Host ""

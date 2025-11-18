# Create DynamoDB Tables for Course Registration System
# Creates all required tables with proper schema

param(
    [string]$Region = "us-east-1",
    [string]$TablePrefix = "CourseReg"
)

Write-Host "=== Creating DynamoDB Tables ===" -ForegroundColor Cyan
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host "Prefix: $TablePrefix" -ForegroundColor Yellow

$tables = @()

# Function to create table
function Create-DynamoDBTable {
    param(
        [string]$TableName,
        [string]$PartitionKey,
        [string]$PartitionKeyType = "S",
        [string]$SortKey = $null,
        [string]$SortKeyType = "S",
        [array]$GlobalIndexes = @()
    )
    
    $fullName = "${TablePrefix}_${TableName}"
    
    Write-Host "`n[Creating] $fullName..." -ForegroundColor Gray
    
    # Build key schema
    $keySchema = @(
        @{
            AttributeName = $PartitionKey
            KeyType = "HASH"
        }
    )
    
    $attributeDefinitions = @(
        @{
            AttributeName = $PartitionKey
            AttributeType = $PartitionKeyType
        }
    )
    
    if ($SortKey) {
        $keySchema += @{
            AttributeName = $SortKey
            KeyType = "RANGE"
        }
        $attributeDefinitions += @{
            AttributeName = $SortKey
            AttributeType = $SortKeyType
        }
    }
    
    # Add attributes for GSIs
    foreach ($gsi in $GlobalIndexes) {
        $attributeDefinitions += @{
            AttributeName = $gsi.PartitionKey
            AttributeType = $gsi.PartitionKeyType
        }
        if ($gsi.SortKey) {
            $attributeDefinitions += @{
                AttributeName = $gsi.SortKey
                AttributeType = $gsi.SortKeyType
            }
        }
    }
    
    # Remove duplicates
    $attributeDefinitions = $attributeDefinitions | Sort-Object -Property AttributeName -Unique
    
    $tableSpec = @{
        TableName = $fullName
        KeySchema = $keySchema
        AttributeDefinitions = $attributeDefinitions
        BillingMode = "PAY_PER_REQUEST"
        Tags = @(
            @{ Key = "Project"; Value = "CourseRegistration" },
            @{ Key = "Environment"; Value = "production" }
        )
    }
    
    # Add GSIs if any
    if ($GlobalIndexes.Count -gt 0) {
        $gsiArray = @()
        foreach ($gsi in $GlobalIndexes) {
            $gsiKeySchema = @(
                @{
                    AttributeName = $gsi.PartitionKey
                    KeyType = "HASH"
                }
            )
            if ($gsi.SortKey) {
                $gsiKeySchema += @{
                    AttributeName = $gsi.SortKey
                    KeyType = "RANGE"
                }
            }
            
            $gsiArray += @{
                IndexName = $gsi.IndexName
                KeySchema = $gsiKeySchema
                Projection = @{
                    ProjectionType = "ALL"
                }
            }
        }
        $tableSpec.GlobalSecondaryIndexes = $gsiArray
    }
    
    $tableJson = $tableSpec | ConvertTo-Json -Depth 10
    $tempFile = ".\temp-table-$TableName.json"
    $tableJson | Out-File -FilePath $tempFile -Encoding utf8
    
    # Create table
    aws dynamodb create-table --cli-input-json "file://$tempFile" --region $Region 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Created $fullName" -ForegroundColor Green
        $script:tables += $fullName
    } else {
        Write-Host "  ⚠ $fullName (may already exist)" -ForegroundColor Yellow
    }
    
    Remove-Item $tempFile -ErrorAction SilentlyContinue
}

# 1. Users table (base user info)
Create-DynamoDBTable -TableName "Users" -PartitionKey "user_id" -GlobalIndexes @(
    @{
        IndexName = "email-index"
        PartitionKey = "email"
        PartitionKeyType = "S"
    }
)

# 2. Students table
Create-DynamoDBTable -TableName "Students" -PartitionKey "student_id" -GlobalIndexes @(
    @{
        IndexName = "user_id-index"
        PartitionKey = "user_id"
        PartitionKeyType = "S"
    },
    @{
        IndexName = "major_id-index"
        PartitionKey = "major_id"
        PartitionKeyType = "S"
    }
)

# 3. Teachers table
Create-DynamoDBTable -TableName "Teachers" -PartitionKey "teacher_id" -GlobalIndexes @(
    @{
        IndexName = "user_id-index"
        PartitionKey = "user_id"
        PartitionKeyType = "S"
    },
    @{
        IndexName = "department_id-index"
        PartitionKey = "department_id"
        PartitionKeyType = "S"
    }
)

# 4. Admins table
Create-DynamoDBTable -TableName "Admins" -PartitionKey "admin_id" -GlobalIndexes @(
    @{
        IndexName = "user_id-index"
        PartitionKey = "user_id"
        PartitionKeyType = "S"
    }
)

# 5. Departments table
Create-DynamoDBTable -TableName "Departments" -PartitionKey "department_id"

# 6. Majors table
Create-DynamoDBTable -TableName "Majors" -PartitionKey "major_id" -GlobalIndexes @(
    @{
        IndexName = "department_id-index"
        PartitionKey = "department_id"
        PartitionKeyType = "S"
    }
)

# 7. Semesters table
Create-DynamoDBTable -TableName "Semesters" -PartitionKey "semester_id"

# 8. Courses table
Create-DynamoDBTable -TableName "Courses" -PartitionKey "course_id" -GlobalIndexes @(
    @{
        IndexName = "department_id-index"
        PartitionKey = "department_id"
        PartitionKeyType = "S"
    },
    @{
        IndexName = "course_code-index"
        PartitionKey = "course_code"
        PartitionKeyType = "S"
    }
)

# 9. Course Sections table
Create-DynamoDBTable -TableName "CourseSections" -PartitionKey "section_id" -GlobalIndexes @(
    @{
        IndexName = "course_id-semester_id-index"
        PartitionKey = "course_id"
        PartitionKeyType = "S"
        SortKey = "semester_id"
        SortKeyType = "S"
    },
    @{
        IndexName = "teacher_id-index"
        PartitionKey = "teacher_id"
        PartitionKeyType = "S"
    }
)

# 10. Classrooms table
Create-DynamoDBTable -TableName "Classrooms" -PartitionKey "classroom_id"

# 11. Course Schedules table
Create-DynamoDBTable -TableName "CourseSchedules" -PartitionKey "schedule_id" -GlobalIndexes @(
    @{
        IndexName = "section_id-index"
        PartitionKey = "section_id"
        PartitionKeyType = "S"
    }
)

# 12. Prerequisites table
Create-DynamoDBTable -TableName "Prerequisites" -PartitionKey "course_id" -SortKey "prerequisite_course_id"

# 13. Enrollments table
Create-DynamoDBTable -TableName "Enrollments" -PartitionKey "enrollment_id" -GlobalIndexes @(
    @{
        IndexName = "student_id-semester_id-index"
        PartitionKey = "student_id"
        PartitionKeyType = "S"
        SortKey = "semester_id"
        SortKeyType = "S"
    },
    @{
        IndexName = "section_id-index"
        PartitionKey = "section_id"
        PartitionKeyType = "S"
    }
)

# 14. Enrollment Status table (for tracking status changes)
Create-DynamoDBTable -TableName "EnrollmentStatus" -PartitionKey "status_id" -GlobalIndexes @(
    @{
        IndexName = "enrollment_id-index"
        PartitionKey = "enrollment_id"
        PartitionKeyType = "S"
    }
)

# 15. Enrollment History table (audit log)
Create-DynamoDBTable -TableName "EnrollmentHistory" -PartitionKey "history_id" -GlobalIndexes @(
    @{
        IndexName = "enrollment_id-timestamp-index"
        PartitionKey = "enrollment_id"
        PartitionKeyType = "S"
        SortKey = "timestamp"
        SortKeyType = "N"
    }
)

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Tables created/verified: $($tables.Count)" -ForegroundColor Green
if ($tables.Count -gt 0) {
    Write-Host "`nCreated tables:" -ForegroundColor Yellow
    foreach ($table in $tables) {
        Write-Host "  - $table" -ForegroundColor White
    }
}

Write-Host "`nNote: Tables are created with PAY_PER_REQUEST billing mode" -ForegroundColor Gray
Write-Host "You can view tables in AWS Console:" -ForegroundColor Gray
Write-Host "https://console.aws.amazon.com/dynamodb/home?region=$Region#tables:" -ForegroundColor Cyan

Write-Host "`nTo list all tables:" -ForegroundColor Yellow
Write-Host "aws dynamodb list-tables --region $Region" -ForegroundColor White

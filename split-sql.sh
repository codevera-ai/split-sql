#!/bin/bash

# SQL File Splitter Script
# Splits a large SQL file into individual table files with CREATE and INSERT statements
# Includes DROP TABLE statements

# Check if arguments are provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <input_sql_file> [--import]"
    echo "       $0 --import-only"
    echo ""
    echo "Examples:"
    echo "  $0 database_dump.sql                 # Split only"
    echo "  $0 database_dump.sql --import        # Split and import"
    echo "  $0 --import-only                     # Import existing split files only"
    echo ""
    echo "Options:"
    echo "  --import       Import the split files into database after splitting"
    echo "  --import-only  Import existing split files without re-splitting"
    exit 1
fi

OUTPUT_DIR="split-sql"
IMPORT_FILES=false
IMPORT_ONLY=false
INPUT_FILE=""

# Database configuration
DB_HOST=""
DB_PORT=""
DB_NAME=""
DB_USER=""
DB_PASSWORD=""
USE_DDEV=false

# Table filtering configuration
EXCLUDE_TABLES=""
CREATE_ONLY_TABLES=""

# Function to show help
show_help() {
    cat << EOF
SQL File Splitter and Importer

DESCRIPTION:
    Splits a large SQL file into individual table files with CREATE and INSERT statements.
    Can optionally import the split files into database using MySQL or ddev.

USAGE:
    $0 <input_sql_file> [OPTIONS]
    $0 --import-only [DB_OPTIONS]
    $0 --help

OPTIONS:
    --import          Import the split files into database after splitting
    --import-only     Import existing split files without re-splitting
    --help            Show this help message

FILTERING OPTIONS:
    --exclude TABLES  Comma-separated list of table names/patterns to exclude entirely
                      (Example: --exclude "_temp,backup_*,old_data")
    --create-only TABLES  Comma-separated list of table names/patterns for create-only
                          (Example: --create-only "cache_*,temp_*")

DATABASE OPTIONS:
    --host HOST       Database host (required for MySQL mode)
    --port PORT       Database port (default: 3306)
    --database DB     Database name (required for MySQL mode)
    --user USER       Database username (required for MySQL mode)
    --password PASS   Database password (optional for MySQL mode)
    --ddev            Use ddev instead of MySQL with credentials

EXAMPLES:
    # Split a large SQL file into individual table files
    $0 database_dump.sql

    # Split and import using MySQL credentials (default)
    $0 database_dump.sql --import --host localhost --database mydb --user root --password secret

    # Split and import using ddev
    $0 database_dump.sql --import --ddev

    # Split excluding specific tables
    $0 database_dump.sql --exclude "_temp,backup_*,old_data"

    # Split with create-only tables and exclusions
    $0 database_dump.sql --exclude "_temp" --create-only "cache_*,temp_*"

    # Import existing split files using MySQL credentials
    $0 --import-only --host localhost --database mydb --user root --password secret

    # Import existing split files using ddev
    $0 --import-only --ddev

    # Import a specific table manually with ddev
    ddev mysql < split-sql/users.sql

    # Import a specific table manually with custom credentials
    mysql -h localhost -u root -psecret mydb < split-sql/users.sql

FILTERING:
    Default filtering rules (can be overridden with --exclude and --create-only):
    - Tables starting with '_' are skipped entirely
    - All other tables get full structure + data

    Use --exclude and --create-only options to customise filtering behaviour.
    Patterns support shell wildcards (* and ?)

OUTPUT:
    Files are created in: split-sql/
    Each file contains:
    - SET FOREIGN_KEY_CHECKS = 0;
    - DROP TABLE IF EXISTS table_name;
    - CREATE TABLE statement
    - INSERT INTO statements (unless filtered)

REQUIREMENTS:
    - For MySQL mode (default): mysql client must be installed and accessible
    - For ddev mode: ddev must be installed and configured
    - Database must be accessible with provided credentials

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --import)
            IMPORT_FILES=true
            shift
            ;;
        --import-only)
            IMPORT_ONLY=true
            shift
            ;;
        --ddev)
            USE_DDEV=true
            shift
            ;;
        --host)
            DB_HOST="$2"
            shift 2
            ;;
        --port)
            DB_PORT="$2"
            shift 2
            ;;
        --database)
            DB_NAME="$2"
            shift 2
            ;;
        --user)
            DB_USER="$2"
            shift 2
            ;;
        --password)
            DB_PASSWORD="$2"
            shift 2
            ;;
        --exclude)
            EXCLUDE_TABLES="$2"
            shift 2
            ;;
        --create-only)
            CREATE_ONLY_TABLES="$2"
            shift 2
            ;;
        *)
            if [ -z "$INPUT_FILE" ] && [ "$IMPORT_ONLY" = false ]; then
                INPUT_FILE="$1"
            fi
            shift
            ;;
    esac
done

# Set default port if not specified
if [ -z "$DB_PORT" ]; then
    DB_PORT="3306"
fi

# Function to import SQL files
import_sql_files() {
    echo "Importing split SQL files into database..."

    # Check if split-sql directory exists
    if [ ! -d "$OUTPUT_DIR" ]; then
        echo "Error: Directory '$OUTPUT_DIR' not found!"
        echo "Run the script without --import-only first to create split files."
        exit 1
    fi

    # Check if there are any SQL files
    if ! ls "$OUTPUT_DIR"/*.sql >/dev/null 2>&1; then
        echo "Error: No .sql files found in '$OUTPUT_DIR' directory!"
        exit 1
    fi

    import_count=0
    failed_imports=0

    echo "Files to import:"
    ls -la "$OUTPUT_DIR"/*.sql

    # Validate database credentials if not using ddev
    if [ "$USE_DDEV" = false ]; then
        if [ -z "$DB_HOST" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ]; then
            echo "Error: For MySQL mode, you must specify --host, --database, and --user (or use --ddev)"
            exit 1
        fi

        # Check if mysql command is available
        if ! command -v mysql >/dev/null 2>&1; then
            echo "Error: mysql command not found. Please install MySQL client."
            exit 1
        fi

        echo "Using MySQL with credentials: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
    else
        # Check if ddev is available
        if ! command -v ddev >/dev/null 2>&1; then
            echo "Error: ddev command not found. Use MySQL with database credentials or install ddev."
            exit 1
        fi
        echo "Using ddev mysql"
    fi

    for sql_file in "$OUTPUT_DIR"/*.sql; do
        if [ -f "$sql_file" ]; then
            filename=$(basename "$sql_file")
            echo "Importing: $filename"

            if [ "$USE_DDEV" = true ]; then
                # Use ddev
                if ddev mysql < "$sql_file"; then
                    ((import_count++))
                    echo "✓ Successfully imported: $filename"
                else
                    ((failed_imports++))
                    echo "✗ Failed to import: $filename"
                fi
            else
                # Use mysql with credentials
                mysql_cmd="mysql -h$DB_HOST -P$DB_PORT -u$DB_USER"
                if [ -n "$DB_PASSWORD" ]; then
                    mysql_cmd="$mysql_cmd -p$DB_PASSWORD"
                fi
                mysql_cmd="$mysql_cmd $DB_NAME"

                if $mysql_cmd < "$sql_file"; then
                    ((import_count++))
                    echo "✓ Successfully imported: $filename"
                else
                    ((failed_imports++))
                    echo "✗ Failed to import: $filename"
                fi
            fi
        fi
    done

    echo ""
    echo "Import summary:"
    echo "Successfully imported: $import_count files"
    if [ $failed_imports -gt 0 ]; then
        echo "Failed imports: $failed_imports files"
    fi
}

# Handle import-only mode
if [ "$IMPORT_ONLY" = true ]; then
    import_sql_files
    exit 0
fi

# Check if input file exists (for split mode)
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File '$INPUT_FILE' not found!"
    exit 1
fi

echo "Splitting SQL file: $INPUT_FILE"
echo "Output directory: $OUTPUT_DIR"

# Show filtering configuration
echo "Table filtering:"
if [ ${#EXCLUDE_ENTIRELY[@]} -gt 0 ]; then
    echo "  Excluding entirely: ${EXCLUDE_ENTIRELY[*]}"
else
    echo "  Excluding entirely: (none)"
fi

if [ ${#CREATE_ONLY[@]} -gt 0 ]; then
    echo "  Create-only tables: ${CREATE_ONLY[*]}"
else
    echo "  Create-only tables: (none)"
fi
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Build filter arrays from command line arguments or use defaults
if [ -n "$EXCLUDE_TABLES" ]; then
    # Convert comma-separated string to array
    IFS=',' read -ra EXCLUDE_ENTIRELY <<< "$EXCLUDE_TABLES"
else
    # Default exclusions
    EXCLUDE_ENTIRELY=(
        "_*"      # Tables starting with underscore - skip entirely
    )
fi

if [ -n "$CREATE_ONLY_TABLES" ]; then
    # Convert comma-separated string to array
    IFS=',' read -ra CREATE_ONLY <<< "$CREATE_ONLY_TABLES"
else
    # Default create-only tables (none by default)
    CREATE_ONLY=()
fi

# Function to check if table should be excluded entirely
should_exclude_entirely() {
    local table_name="$1"
    for pattern in "${EXCLUDE_ENTIRELY[@]}"; do
        if [[ $table_name == $pattern ]]; then
            return 0  # Should exclude entirely
        fi
    done
    return 1  # Should not exclude
}

# Function to check if table should be create-only (no data)
is_create_only() {
    local table_name="$1"
    for pattern in "${CREATE_ONLY[@]}"; do
        if [[ $table_name == $pattern ]]; then
            return 0  # Is create-only
        fi
    done
    return 1  # Not create-only
}

# Initialize variables
current_table=""
current_file=""
in_create_table=false
in_insert_data=false
buffer=""

# Process the SQL file line by line to prevent memory issues
while IFS= read -r line || [[ -n "$line" ]]; do
    # Detect CREATE TABLE statements
    if [[ $line =~ ^[[:space:]]*CREATE[[:space:]]+TABLE[[:space:]]+\`?([^[:space:]\`]+)\`? ]] || [[ $line =~ ^[[:space:]]*CREATE[[:space:]]+TABLE[[:space:]]+IF[[:space:]]+NOT[[:space:]]+EXISTS[[:space:]]+\`?([^[:space:]\`]+)\`? ]]; then
        # Extract table name
        if [[ $line =~ \`([^[:space:]\`]+)\` ]]; then
            current_table="${BASH_REMATCH[1]}"
        else
            # Fallback for tables without backticks
            current_table=$(echo "$line" | sed -n 's/.*TABLE[[:space:]]\+\(IF[[:space:]]\+NOT[[:space:]]\+EXISTS[[:space:]]\+\)\?\([^[:space:](]\+\).*/\2/p')
        fi

        # Check if table should be excluded entirely
        if should_exclude_entirely "$current_table"; then
            echo "Skipping excluded table: $current_table"
            current_table=""
            current_file=""
            in_create_table=false
            in_insert_data=false
            continue
        fi

        # Check if table is create-only
        if is_create_only "$current_table"; then
            echo "Processing table (create-only): $current_table"
        else
            echo "Processing table: $current_table"
        fi

        current_file="$OUTPUT_DIR/${current_table}.sql"
        in_create_table=true
        in_insert_data=false

        # Start new file with foreign key checks disabled and DROP TABLE
        cat > "$current_file" << EOF
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS \`$current_table\`;

EOF
        echo "$line" >> "$current_file"

    # Detect INSERT statements for current table
    elif [[ $line =~ ^[[:space:]]*INSERT[[:space:]]+INTO[[:space:]]+\`?$current_table\`? ]] && [[ -n "$current_table" ]]; then
        # Skip INSERT statements for create-only tables
        if is_create_only "$current_table"; then
            continue
        fi
        in_insert_data=true
        in_create_table=false
        echo "$line" >> "$current_file"

    # Handle multi-line CREATE TABLE statements
    elif [[ $in_create_table == true ]]; then
        echo "$line" >> "$current_file"
        # Check if CREATE TABLE statement ends
        if [[ $line =~ \;[[:space:]]*$ ]]; then
            in_create_table=false
            echo "" >> "$current_file"  # Add blank line after CREATE TABLE
        fi

    # Handle INSERT data
    elif [[ $in_insert_data == true ]]; then
        # Skip INSERT data for create-only tables
        if is_create_only "$current_table"; then
            if [[ $line =~ \;[[:space:]]*$ ]]; then
                in_insert_data=false
            fi
            continue
        fi
        echo "$line" >> "$current_file"
        # Check if INSERT statement ends (semicolon at end of line)
        if [[ $line =~ \;[[:space:]]*$ ]]; then
            in_insert_data=false
        fi

    # Handle LOCK/UNLOCK TABLES statements
    elif [[ $line =~ ^[[:space:]]*LOCK[[:space:]]+TABLES[[:space:]]+\`?$current_table\`? ]] && [[ -n "$current_table" ]]; then
        echo "$line" >> "$current_file"
    elif [[ $line =~ ^[[:space:]]*UNLOCK[[:space:]]+TABLES ]] && [[ -n "$current_table" ]]; then
        echo "$line" >> "$current_file"

    # Skip foreign key check statements
    elif [[ $line =~ ^[[:space:]]*SET[[:space:]]+FOREIGN_KEY_CHECKS[[:space:]]*= ]]; then
        continue

    # Reset table context when we hit another table or end of data
    elif [[ $line =~ ^[[:space:]]*CREATE[[:space:]]+TABLE ]] || [[ $line =~ ^[[:space:]]*-- ]] || [[ $line =~ ^[[:space:]]*$ ]]; then
        continue
    fi

done < "$INPUT_FILE"

# Processing complete

echo "SQL file splitting completed!"
echo "Individual table files created in: $OUTPUT_DIR/"
echo ""
echo "Files created:"
ls -la "$OUTPUT_DIR/"*.sql | wc -l | xargs echo "Total files:"
ls -la "$OUTPUT_DIR/"

# Import files if requested
if [ "$IMPORT_FILES" = true ]; then
    echo ""
    import_sql_files
else
    echo ""
    echo "To import a specific table:"
    echo "mysql -u username -p database_name < $OUTPUT_DIR/table_name.sql"
    echo ""
    echo "Or with ddev:"
    echo "ddev mysql < $OUTPUT_DIR/table_name.sql"
    echo ""
    echo "To import all split files:"
    echo "$0 --import-only"
    echo ""
    echo "To split and import in one go:"
    echo "$0 $INPUT_FILE --import"
fi
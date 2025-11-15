# SQL File Splitter

A bash script that splits large SQL database dumps into individual table files, making it easier to import large databases by processing one table at a time.

## Features

- **Split SQL dumps** into individual table files
- **Smart filtering** with configurable rules
- **Import functionality** with MySQL or ddev support
- **Structure-only mode** for specific table patterns
- **Safe imports** with foreign key checks disabled
- **Comprehensive error handling**

## Installation

1. Download or clone the script:
```bash
git clone https://github.com/codevera-ai/split-sql.git
cd split-sql
```

2. Make the script executable:
```bash
chmod +x split-sql.sh
```

## Quick Start

```bash
# Basic split - creates files in split-sql/ directory
./split-sql.sh database_dump.sql

# Split and import using MySQL (default)
./split-sql.sh database_dump.sql --import --host localhost --database mydb --user root --password secret

# Split and import using ddev
./split-sql.sh database_dump.sql --import --ddev

# Import existing split files
./split-sql.sh --import-only --host localhost --database mydb --user root
```

## Usage

### Split SQL File
```bash
./split-sql.sh <input_sql_file> [OPTIONS]
```

### Import Only Mode
```bash
./split-sql.sh --import-only [DB_OPTIONS]
```

### Available Options

| Option | Description |
|--------|-------------|
| `--import` | Import split files after splitting |
| `--import-only` | Import existing files without re-splitting |
| `--help` | Show detailed help message |
| `--exclude TABLES` | Comma-separated list of table patterns to exclude entirely |
| `--create-only TABLES` | Comma-separated list of table patterns for structure-only |
| `--ddev` | Use ddev instead of MySQL |
| `--host HOST` | Database host |
| `--port PORT` | Database port (default: 3306) |
| `--database DB` | Database name |
| `--user USER` | Database username |
| `--password PASS` | Database password |

## Examples

### Basic Usage
```bash
# Split a large SQL file
./split-sql.sh backup.sql

# Split and import with ddev
./split-sql.sh backup.sql --import --ddev
```

### MySQL Connection (Default)
```bash
# Split and import with MySQL credentials
./split-sql.sh backup.sql --import \
  --host localhost --database myapp --user root --password secret

# Import only with MySQL credentials
./split-sql.sh --import-only \
  --host localhost --database myapp --user root --password secret
```

### Using ddev
```bash
# Split and import with ddev
./split-sql.sh backup.sql --import --ddev

# Import only with ddev
./split-sql.sh --import-only --ddev
```

### Table Filtering
```bash
# Exclude specific tables entirely
./split-sql.sh backup.sql --exclude "_temp,backup_*,old_data"

# Create structure-only for specific tables
./split-sql.sh backup.sql --create-only "cache_*,temp_*"

# Combine exclusions and create-only
./split-sql.sh backup.sql --exclude "_temp" --create-only "cache_*,session_*"
```

### Manual Import
```bash
# Import specific table with ddev
ddev mysql < split-sql/users.sql

# Import specific table with MySQL
mysql -h localhost -u root -psecret mydb < split-sql/users.sql
```

## Table Filtering Rules

The script applies intelligent filtering based on table names:

### Default Behaviour
- **Skip entirely**: Tables starting with `_` (underscore)
- **Full export**: All other tables (structure + data)

### Custom Filtering
Use the `--exclude` and `--create-only` options to customise filtering:

- **`--exclude`**: Comma-separated list of table patterns to skip entirely
- **`--create-only`**: Comma-separated list of table patterns for structure-only (no data)

Patterns support shell wildcards (`*` and `?`):
- `cache_*` matches `cache_users`, `cache_sessions`, etc.
- `temp_??` matches `temp_01`, `temp_02`, etc.
- `old_data` matches exactly `old_data`

## Output Structure

Each generated file contains:

1. `SET FOREIGN_KEY_CHECKS = 0;`
2. `DROP TABLE IF EXISTS table_name;`
3. `CREATE TABLE` statement
4. `INSERT INTO` statements (unless filtered out)

Files are created in the `split-sql/` directory with the naming pattern: `{table_name}.sql`

## Requirements

### For MySQL Mode (Default)
- MySQL client installed
- Database connection credentials
- Accessible MySQL server

### For ddev Mode
- ddev installed and configured
- Active ddev environment

## Error Handling

The script includes comprehensive error checking:

- Validates input file exists
- Checks for required commands (ddev/mysql)
- Verifies database credentials
- Reports import success/failure for each file
- Provides detailed error messages

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is open source and available under the [MIT License](LICENSE).

## Author

**Billy Patel**
- Website: [billymedia.co.uk](https://billymedia.co.uk)
- Email: billy@billymedia.co.uk

## Support

If you encounter any issues or have questions:

1. Check the help output: `./split-sql.sh --help`
2. Open an issue on GitHub
3. Contact the author directly

---

*This tool is particularly useful for developers working with large database dumps who need to selectively import tables or manage database schemas in version control.*
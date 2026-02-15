<?php

define( 'CLAUDE_DIR', getenv( 'HOME' ) . '/.claude' );
define( 'PROJECTS_DIR', CLAUDE_DIR . '/projects' );

// colors
function info( $msg ) { echo "\033[34m→\033[0m $msg\n"; }
function ok( $msg ) { echo "\033[32m✓\033[0m $msg\n"; }
function warn( $msg ) { echo "\033[33m!\033[0m $msg\n"; }
function err( $msg ) { echo "\033[31m✗\033[0m $msg\n"; }

function parse_args( $argv ) {
  $opts = [
    'write' => false,
    'verbose' => false,
    'project' => null,
  ];

  for ( $i = 1; $i < count( $argv ); $i++ ) {
    switch ( $argv[$i] ) {
      case '--write':
        $opts['write'] = true;
        break;
      case '--verbose':
      case '-v':
        $opts['verbose'] = true;
        break;
      case '--project':
        $opts['project'] = $argv[++$i] ?? null;
        break;
      case '--help':
      case '-h':
        echo "Usage: php claude-code-session-sync.php [options]\n\n";
        echo "Options:\n";
        echo "  --write          Write changes to session indexes (default: dry-run)\n";
        echo "  --project <path> Sync only a specific project (original path or encoded name)\n";
        echo "  --verbose, -v    Show details about each discovered session\n";
        echo "  --help, -h       Show this help\n";
        exit( 0 );
    }
  }

  return $opts;
}

function encode_project_path( $path ) {
  return '-' . str_replace( '/', '-', ltrim( $path, '/' ) );
}

function resolve_original_path( $project_dir ) {
  // try existing index first
  $index_path = $project_dir . '/sessions-index.json';

  if ( file_exists( $index_path ) ) {
    $data = json_decode( file_get_contents( $index_path ), true );

    if ( isset( $data['originalPath'] ) ) {
      return $data['originalPath'];
    }
  }

  // try extracting from first .jsonl file with a cwd field
  foreach ( glob( $project_dir . '/*.jsonl' ) as $jsonl ) {
    $handle = fopen( $jsonl, 'r' );

    if ( !$handle ) continue;

    while ( ( $line = fgets( $handle ) ) !== false ) {
      $event = json_decode( trim( $line ), true );

      if ( isset( $event['cwd'] ) ) {
        fclose( $handle );
        return $event['cwd'];
      }
    }

    fclose( $handle );
  }

  // fallback: encoded name (lossy but better than nothing)
  return basename( $project_dir );
}

function get_project_dirs( $filter = null ) {
  $dirs = [];

  foreach ( glob( PROJECTS_DIR . '/*', GLOB_ONLYDIR ) as $dir ) {
    $encoded = basename( $dir );

    if ( $filter !== null ) {
      if ( $encoded !== $filter && $encoded !== encode_project_path( $filter ) ) {
        continue;
      }
    }

    $dirs[] = [
      'path' => $dir,
      'encoded' => $encoded,
    ];
  }

  // resolve original paths (deferred to avoid unnecessary I/O when filtering)
  foreach ( $dirs as &$d ) {
    $d['original_path'] = resolve_original_path( $d['path'] );
  }

  // if filter looks like an original path, re-filter
  if ( $filter !== null && count( $dirs ) === 0 ) {
    foreach ( glob( PROJECTS_DIR . '/*', GLOB_ONLYDIR ) as $dir ) {
      $original = resolve_original_path( $dir );

      if ( $original === $filter ) {
        $dirs[] = [
          'path' => $dir,
          'encoded' => basename( $dir ),
          'original_path' => $original,
        ];
      }
    }
  }

  return $dirs;
}

function read_index( $project_dir ) {
  $index_path = $project_dir . '/sessions-index.json';

  if ( !file_exists( $index_path ) ) {
    return null;
  }

  $data = json_decode( file_get_contents( $index_path ), true );

  if ( !$data || !isset( $data['entries'] ) ) {
    return null;
  }

  return $data;
}

function get_indexed_session_ids( $index ) {
  if ( !$index ) {
    return [];
  }

  return array_map( fn( $e ) => $e['sessionId'], $index['entries'] );
}

function discover_jsonl_files( $project_dir ) {
  // only top-level .jsonl files (not subagent files in subdirectories)
  return glob( $project_dir . '/*.jsonl' );
}

function extract_session_id( $jsonl_path ) {
  return pathinfo( $jsonl_path, PATHINFO_FILENAME );
}

function parse_jsonl_metadata( $jsonl_path ) {
  $handle = fopen( $jsonl_path, 'r' );

  if ( !$handle ) {
    return null;
  }

  $first_prompt = null;
  $first_timestamp = null;
  $last_timestamp = null;
  $message_count = 0;
  $git_branch = null;
  $project_path = null;
  $is_sidechain = false;
  $session_id = extract_session_id( $jsonl_path );

  while ( ( $line = fgets( $handle ) ) !== false ) {
    $line = trim( $line );

    if ( empty( $line ) ) {
      continue;
    }

    $event = json_decode( $line, true );

    if ( !$event ) {
      continue;
    }

    // track timestamps
    $ts = $event['timestamp'] ?? null;

    if ( $ts ) {
      if ( $first_timestamp === null ) {
        $first_timestamp = $ts;
      }
      $last_timestamp = $ts;
    }

    // extract metadata from first meaningful message
    if ( $git_branch === null && isset( $event['gitBranch'] ) ) {
      $git_branch = $event['gitBranch'];
    }

    if ( $project_path === null && isset( $event['cwd'] ) ) {
      $project_path = $event['cwd'];
    }

    if ( isset( $event['isSidechain'] ) && $event['isSidechain'] ) {
      $is_sidechain = true;
    }

    // override session ID from file content if available
    if ( isset( $event['sessionId'] ) && $session_id === extract_session_id( $jsonl_path ) ) {
      $session_id = $event['sessionId'];
    }

    $type = $event['type'] ?? null;

    if ( $type === 'user' || $type === 'assistant' ) {
      $message_count++;
    }

    // first user prompt
    if ( $type === 'user' && $first_prompt === null ) {
      $content = $event['message']['content'] ?? null;

      if ( is_string( $content ) ) {
        $first_prompt = $content;
      } elseif ( is_array( $content ) ) {
        // find the last text block (earlier ones are often IDE context)
        $texts = array_filter( $content, fn( $c ) => ( $c['type'] ?? '' ) === 'text' );

        if ( !empty( $texts ) ) {
          $last_text = end( $texts );
          $first_prompt = $last_text['text'] ?? null;
        }
      }

      if ( $first_prompt ) {
        // strip XML-like tags (IDE context)
        $first_prompt = preg_replace( '/<[^>]+>.*?<\/[^>]+>/s', '', $first_prompt );
        $first_prompt = trim( $first_prompt );

        if ( empty( $first_prompt ) ) {
          $first_prompt = null;
        }
      }
    }
  }

  fclose( $handle );

  if ( $first_timestamp === null ) {
    // empty or unparseable file
    $stat = stat( $jsonl_path );
    $first_timestamp = date( 'c', $stat['ctime'] );
    $last_timestamp = date( 'c', $stat['mtime'] );
  }

  return [
    'sessionId' => $session_id,
    'fullPath' => realpath( $jsonl_path ),
    'fileMtime' => (int) ( filemtime( $jsonl_path ) * 1000 ),
    'firstPrompt' => $first_prompt ? mb_substr( $first_prompt, 0, 200 ) : 'No prompt',
    'messageCount' => $message_count,
    'created' => $first_timestamp,
    'modified' => $last_timestamp,
    'gitBranch' => $git_branch ?? 'main',
    'projectPath' => $project_path,
    'isSidechain' => $is_sidechain,
  ];
}

function backup_index( $project_dir ) {
  $src = $project_dir . '/sessions-index.json';

  if ( file_exists( $src ) ) {
    copy( $src, $src . '.bak' );
  }
}

function write_index( $project_dir, $index ) {
  $path = $project_dir . '/sessions-index.json';
  $json = json_encode( $index, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES );
  file_put_contents( $path, $json . "\n" );
}

// --- main ---

$opts = parse_args( $argv );
$projects = get_project_dirs( $opts['project'] );

if ( empty( $projects ) ) {
  err( 'No project directories found' . ( $opts['project'] ? " matching '{$opts['project']}'" : '' ) );
  exit( 1 );
}

$total_missing = 0;
$total_synced = 0;

foreach ( $projects as $project ) {
  $index = read_index( $project['path'] );
  $indexed_ids = get_indexed_session_ids( $index );
  $jsonl_files = discover_jsonl_files( $project['path'] );

  if ( empty( $jsonl_files ) ) {
    continue;
  }

  // find orphaned sessions
  $orphaned = [];

  foreach ( $jsonl_files as $jsonl ) {
    $sid = extract_session_id( $jsonl );

    if ( !in_array( $sid, $indexed_ids ) ) {
      $orphaned[] = $jsonl;
    }
  }

  $total_on_disk = count( $jsonl_files );
  $total_indexed = count( $indexed_ids );
  $total_orphaned = count( $orphaned );

  if ( $total_orphaned === 0 && !$opts['verbose'] ) {
    continue;
  }

  echo "\n\033[1m{$project['original_path']}\033[0m\n";
  info( "$total_on_disk sessions on disk, $total_indexed indexed, $total_orphaned missing from index" );

  if ( $total_orphaned === 0 ) {
    ok( 'All sessions indexed' );
    continue;
  }

  $total_missing += $total_orphaned;
  $new_entries = [];

  foreach ( $orphaned as $jsonl ) {
    $meta = parse_jsonl_metadata( $jsonl );

    if ( !$meta ) {
      warn( "Could not parse: " . basename( $jsonl ) );
      continue;
    }

    $new_entries[] = $meta;

    if ( $opts['verbose'] ) {
      $prompt_preview = mb_substr( $meta['firstPrompt'], 0, 60 );
      info( "  {$meta['sessionId']} — \"{$prompt_preview}\" ({$meta['messageCount']} msgs, {$meta['created']})" );
    }
  }

  if ( $opts['write'] && !empty( $new_entries ) ) {
    backup_index( $project['path'] );

    if ( $index === null ) {
      $index = [
        'version' => 1,
        'entries' => [],
        'originalPath' => $project['original_path'],
      ];
    }

    $index['entries'] = array_merge( $index['entries'], $new_entries );
    write_index( $project['path'], $index );
    ok( "Added " . count( $new_entries ) . " sessions to index" );
    $total_synced += count( $new_entries );
  } else {
    warn( "$total_orphaned sessions would be added" . ( !$opts['write'] ? ' (dry-run, use --write to apply)' : '' ) );
  }
}

echo "\n";

if ( $total_missing === 0 ) {
  ok( "All sessions are indexed across " . count( $projects ) . " projects" );
} elseif ( $opts['write'] ) {
  ok( "Synced $total_synced sessions across " . count( $projects ) . " projects" );
} else {
  warn( "$total_missing sessions missing from indexes (dry-run)" );
  info( "Run with --write to update indexes" );
}

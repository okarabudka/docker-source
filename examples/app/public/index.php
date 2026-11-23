<?php

declare(strict_types=1);

$checks = [];

try {
    $pdo = new PDO(getenv('DATABASE_DSN'), getenv('DATABASE_USER'), getenv('DATABASE_PASSWORD'));
    $checks['MariaDB'] = 'connected, server ' . $pdo->query('SELECT VERSION()')->fetchColumn();
} catch (PDOException $e) {
    $checks['MariaDB'] = 'failed: ' . $e->getMessage();
}

if (isset($_GET['mail'])) {
    $sent = mail('dev@example.com', 'Hello from PHP ' . PHP_VERSION, 'Sent with mail() through msmtp.', 'From: app@example.com');
    $checks['Mail'] = $sent ? 'sent, see Mailpit on port 8025' : 'mail() failed';
} else {
    $checks['Mail'] = '<a href="?mail=1">send a test mail</a>';
}

$checks['PHP'] = PHP_VERSION . ' (' . PHP_SAPI . ')';
$checks['User'] = posix_getpwuid(posix_geteuid())['name'];
$checks['Xdebug'] = extension_loaded('xdebug') ? (implode(', ', xdebug_info('mode')) ?: 'loaded, off') : 'not loaded';
$checks['Extensions'] = implode(', ', get_loaded_extensions());
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>PHP example</title>
    <style>
        body { font: 16px/1.5 system-ui, sans-serif; margin: 2rem auto; max-width: 48rem; padding: 0 1rem; }
        th { text-align: left; padding-right: 1rem; vertical-align: top; }
    </style>
</head>
<body>
<h1>It works</h1>
<table>
    <?php foreach ($checks as $name => $value): ?>
        <tr><th><?= htmlspecialchars($name) ?></th><td><?= $name === 'Mail' ? $value : htmlspecialchars($value) ?></td></tr>
    <?php endforeach ?>
</table>
</body>
</html>

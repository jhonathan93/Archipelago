<?php

header('Access-Control-Allow-Origin: *');

$services = [
    'mysql' => [
        'host' => 'mysql_db',
        'port' => 3306,
        'username' => 'root',
        'password' => 'admin123',
        'database' => 'minha_app'
    ],
    'redis' => [
        'host' => 'redis_cache',
        'port' => 6379,
        'password' => 'admin123'
    ],
    'mailhog' => [
        'host' => 'mailhog',
        'port' => 1025
    ]
];

$results = [
    'timestamp' => date('Y-m-d H:i:s'),
    'archipelago_status' => 'checking',
    'services' => []
];

function checkMySQL($config): array {
    try {
        $start = microtime(true);
        $dsn = "mysql:host={$config['host']};port={$config['port']};dbname={$config['database']};charset=utf8mb4";

        $pdo = new PDO($dsn, $config['username'], $config['password'], [
                PDO::ATTR_TIMEOUT => 5,
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
        ]);

        $stmt = $pdo->query("SELECT VERSION() as version, NOW() as server_time");
        $info = $stmt->fetch(PDO::FETCH_ASSOC);

        $response_time = round((microtime(true) - $start) * 1000, 2);

        return [
            'status' => 'healthy',
            'response_time_ms' => $response_time,
            'version' => $info['version'],
            'server_time' => $info['server_time'],
            'connection' => "{$config['host']}:{$config['port']}"
        ];
    } catch (Exception $e) {
        return [
            'status' => 'unhealthy',
            'error' => $e->getMessage(),
            'connection' => "{$config['host']}:{$config['port']}"
        ];
    }
}

function checkRedis($config): array {
    try {
        $start = microtime(true);
        $socket = @fsockopen($config['host'], $config['port'], $errno, $errstr, 5);

        if (!$socket) throw new Exception("Connection failed: $errstr ($errno)");

        if (!empty($config['password'])) {
            fwrite($socket, "*2\r\n\$4\r\nAUTH\r\n\$" . strlen($config['password']) . "\r\n{$config['password']}\r\n");
            $auth_response = fgets($socket);

            if (!str_starts_with($auth_response, '+OK')) throw new Exception("Authentication failed: " . trim($auth_response));
        }

        fwrite($socket, "*1\r\n\$4\r\nPING\r\n");
        $ping_response = fgets($socket);
        fwrite($socket, "*2\r\n\$4\r\nINFO\r\n\$6\r\nSERVER\r\n");
        $info_length = fgets($socket);
        $info_data = '';

        if ($info_length && $info_length[0] === '$') {
            $length = (int)substr($info_length, 1);

            if ($length > 0) {
                $info_data = fread($socket, $length);
                fgets($socket);
            }
        }

        $test_key = 'archipelago_health_' . time();
        fwrite($socket, "*3\r\n\$3\r\nSET\r\n\$" . strlen($test_key) . "\r\n{$test_key}\r\n\$2\r\nOK\r\n");
        fgets($socket);
        fwrite($socket, "*2\r\n\$3\r\nGET\r\n\$" . strlen($test_key) . "\r\n{$test_key}\r\n");
        $get_length = fgets($socket);
        $get_value = '';

        if ($get_length && $get_length[0] === '$') {
            $length = (int)substr($get_length, 1);

            if ($length > 0) {
                $get_value = fread($socket, $length);
                fgets($socket);
            }
        }

        fwrite($socket, "*2\r\n\$3\r\nDEL\r\n\$" . strlen($test_key) . "\r\n{$test_key}\r\n");
        fgets($socket);
        fclose($socket);
        $response_time = round((microtime(true) - $start) * 1000, 2);
        $version = 'unknown';

        if (preg_match('/redis_version:([\d.]+)/', $info_data, $matches))  $version = $matches[1];

        return [
            'status' => 'healthy',
            'response_time_ms' => $response_time,
            'ping' => str_starts_with($ping_response, '+PONG') ? 'PONG' : 'ERROR',
            'test_write_read' => $get_value === 'OK' ? 'success' : 'failed',
            'version' => $version,
            'connection' => "{$config['host']}:{$config['port']}"
        ];
    } catch (Exception $e) {
        return [
            'status' => 'unhealthy',
            'error' => $e->getMessage(),
            'connection' => "{$config['host']}:{$config['port']}"
        ];
    }
}

function checkMailHog($config): array {
    try {
        $start = microtime(true);
        $socket = @fsockopen($config['host'], $config['port'], $errno, $errstr, 5);

        if (!$socket) throw new Exception("Connection failed: $errstr ($errno)");

        $response = fgets($socket);
        $response_code = substr($response, 0, 3);

        if ($response_code !== '220') throw new Exception("Invalid SMTP response: $response");

        fputs($socket, "ELO archipelago.local\r\n");
        $elo_response = fgets($socket);
        fputs($socket, "QUIT\r\n");
        fclose($socket);

        $response_time = round((microtime(true) - $start) * 1000, 2);

        return [
            'status' => 'healthy',
            'response_time_ms' => $response_time,
            'smtp_response' => trim($response),
            'elo_response' => trim($elo_response),
            'connection' => "{$config['host']}:{$config['port']}"
        ];
    } catch (Exception $e) {
        return [
            'status' => 'unhealthy',
            'error' => $e->getMessage(),
            'connection' => "{$config['host']}:{$config['port']}"
        ];
    }
}

$results['services']['mysql'] = checkMySQL($services['mysql']);
$results['services']['redis'] = checkRedis($services['redis']);
$results['services']['mailhog'] = checkMailHog($services['mailhog']);
$healthy_count = 0;
$total_services = count($results['services']);

foreach ($results['services'] as $service) {
    if ($service['status'] === 'healthy') $healthy_count++;
}

if ($healthy_count === $total_services) {
    $results['archipelago_status'] = 'healthy';
    $results['message'] = '🏝️ Todas as ilhas do Archipelago estão conectadas!';
} elseif ($healthy_count > 0) {
    $results['archipelago_status'] = 'partial';
    $results['message'] = "⚠️ {$healthy_count}/{$total_services} serviços funcionando";
} else {
    $results['archipelago_status'] = 'unhealthy';
    $results['message'] = '🔴 Nenhum serviço está respondendo';
}

$results['summary'] = [
    'healthy_services' => $healthy_count,
    'total_services' => $total_services,
    'health_percentage' => round((float)$healthy_count / (float)$total_services * 100, 1)
];
?>

<!DOCTYPE html>
<html lang="pt-BR">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">

        <title>🏝️ Archipelago Health Check</title>

        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background: #f5f7fa; }
            .container { max-width: 800px; margin: 0 auto; }
            .header { text-align: center; margin-bottom: 30px; }
            .status-card { background: white; padding: 20px; margin: 15px 0; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
            .healthy { border-left: 5px solid #4caf50; }
            .unhealthy { border-left: 5px solid #f44336; }
            .partial { border-left: 5px solid #ff9800; }
            .service-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 15px; }
            .metric { display: inline-block; margin: 5px 10px 5px 0; padding: 5px 10px; background: #f0f2f5; border-radius: 4px; font-size: 0.9em; }
            .error { color: #f44336; font-weight: bold; }
            pre { background: #f8f9fa; padding: 10px; border-radius: 4px; overflow-x: auto; }
        </style>
    </head>

    <body>
        <div class="container">
            <div class="header">
                <h1>🏝️ Archipelago Health Check - App3</h1>
                <p>Status dos serviços em <strong><?= $results['timestamp'] ?></strong></p>
            </div>

            <div class="status-card <?= $results['archipelago_status'] ?>">
                <h2><?= $results['message'] ?></h2>
                <div class="metric">Serviços Saudáveis: <?= $results['summary']['healthy_services'] ?>/<?= $results['summary']['total_services'] ?></div>
                <div class="metric">Saúde Geral: <?= $results['summary']['health_percentage'] ?>%</div>
            </div>

            <div class="service-grid">
                <?php foreach ($results['services'] as $name => $service): ?>
                    <div class="status-card <?= $service['status'] ?>">
                        <h3><?= strtoupper($name) ?></h3>

                        <div class="metric">Status: <strong><?= $service['status'] ?></strong></div>

                        <?php if (isset($service['response_time_ms'])): ?>
                            <div class="metric">Tempo: <?= $service['response_time_ms'] ?>ms</div>
                        <?php endif; ?>

                        <div class="metric">Conexão: <?= $service['connection'] ?></div>

                        <?php if ($service['status'] === 'unhealthy'): ?>
                            <div class="error">Erro: <?= $service['error'] ?></div>
                        <?php endif; ?>

                        <?php if ($name === 'mysql' && $service['status'] === 'healthy'): ?>
                            <div class="metric">Versão: <?= $service['version'] ?></div>
                            <div class="metric">Hora do Servidor: <?= $service['server_time'] ?></div>
                        <?php endif; ?>

                        <?php if ($name === 'redis' && $service['status'] === 'healthy'): ?>
                            <div class="metric">Versão: <?= $service['version'] ?></div>
                            <div class="metric">Ping: <?= $service['ping'] ?></div>
                            <div class="metric">Teste Write/Read: <?= $service['test_write_read'] ?></div>
                        <?php endif; ?>

                        <?php if ($name === 'mailhog' && $service['status'] === 'healthy'): ?>
                            <div class="metric">SMTP: <?= substr($service['smtp_response'], 0, 50) ?>...</div>
                        <?php endif; ?>
                    </div>
                <?php endforeach; ?>
            </div>

            <div class="status-card">
                <h3>📊 Dados Completos (JSON)</h3>
                <pre><?= json_encode($results, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) ?></pre>
            </div>
        </div>
    </body>
</html>
#!/bin/bash
set -e  # Выход при первой ошибке

echo "🔄 Инициализация config server..."

docker compose exec -T configSrv1 mongosh --port 27017  <<'EOF'
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv1:27017" }
  ]
});
EOF

echo "⏳ Ожидание выбора primary в config_server..."
sleep 5

echo "🔄 Инициализация shard1 (реплика-сет из 3 узлов)..."
docker compose exec -T shard1_1 mongosh --port 27018 <<'EOF'
rs.initiate({
  _id: "shard1",
  members: [
    { _id: 0, host: "shard1_1:27018" },
    { _id: 1, host: "shard1_2:27018" },
    { _id: 2, host: "shard1_3:27018" }
  ]
});
EOF

echo "⏳ Ожидание выбора primary в shard1..."
sleep 5

echo "🔄 Инициализация shard2 (реплика-сет из 3 узлов)..."
docker compose exec -T shard2_1 mongosh --port 27019 <<'EOF'
rs.initiate({
  _id: "shard2",
  members: [
    { _id: 0, host: "shard2_1:27019" },
    { _id: 1, host: "shard2_2:27019" },
    { _id: 2, host: "shard2_3:27019" }
  ]
});
EOF

echo "⏳ Ожидание выбора primary в shard2..."
sleep 5

echo "🔄 Настройка mongos и подключение шардов..."
docker compose exec -T mongos_router mongosh --port 27020 <<'EOF'
// Подключаем шарды (указываем все узлы для отказоустойчивости)
sh.addShard("shard1/shard1_1:27018,shard1_2:27018,shard1_3:27018");
sh.addShard("shard2/shard2_1:27019,shard2_2:27019,shard2_3:27019");

// Включаем шардирование для БД
sh.enableSharding("somedb");

// Шардируем коллекцию с hashed-индексом по полю name
sh.shardCollection("somedb.helloDoc", { "name": "hashed" });

// Тестовые данные
use somedb;
for (var i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({ age: i, name: "ly" + i });
}

print("✅ Документов в коллекции:", db.helloDoc.countDocuments());
print("✅ Статус шардинга:");
sh.status();
EOF

echo "🎉 Инициализация завершена!"
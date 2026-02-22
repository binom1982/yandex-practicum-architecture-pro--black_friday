#!/bin/bash

echo "🔄 Инициализация config server..."

docker compose exec -T configSrv mongosh --port 27017 <<EOF
rs.initiate(
  {
    _id : "config_server",
       configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27017" }
    ]
  }
);
exit();
EOF

# sleep 10  # Ждём выбора primary

echo "🔄 Инициализация shard1..."
docker compose exec -T shard1 mongosh --port 27018 <<'EOF'
rs.initiate(
    {
      _id : "shard1",
      members: [
        { _id : 0, host : "shard1:27018" },
      ]
    }
);
exit();
EOF

# sleep 10
echo "🔄 Инициализация shard2..."
docker compose exec -T shard2 mongosh --port 27019 <<EOF
rs.initiate(
    {
      _id : "shard2",
      members: [
        { _id : 0, host : "shard2:27019" }
      ]
    }
  );
exit();
EOF

# sleep 15  # Даём время на стабилизацию всех реплика-сетов

echo "🔄 Настройка mongos и шардирование..."
# Инициализация роутера и наполнение его тестовыми данными:
docker compose exec -T mongos_router mongosh --port 27020 <<EOF
// Добавляем шарды

sh.addShard( "shard1/shard1:27018");
sh.addShard( "shard2/shard2:27019");

// Включаем шардирование для БД
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )

// Тестовые данные
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insert({age:i, name:"ly"+i})

print("Документов:", db.helloDoc.countDocuments());
exit();
EOF

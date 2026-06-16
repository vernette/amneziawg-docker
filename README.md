<p align="center">
  <img src=".github/assets/logo.png" alt="AmneziaWG" width="500">
</p>

<p align="center">
  <a href="https://hub.docker.com/r/vernette/amneziawg"><img src="https://img.shields.io/docker/pulls/vernette/amneziawg?logo=docker" alt="Docker Pulls"></a>
  <a href="https://hub.docker.com/r/vernette/amneziawg/tags"><img src="https://img.shields.io/docker/v/vernette/amneziawg?sort=semver&logo=docker" alt="Docker Image Version"></a>
  <a href="https://github.com/vernette/amneziawg-docker-client/actions/workflows/docker-build.yaml"><img src="https://img.shields.io/github/actions/workflow/status/vernette/amneziawg-docker-client/docker-build.yaml" alt="Build"></a>
</p>

Актуальный Docker контейнер [AmneziaWG](https://docs.amnezia.org/ru/documentation/amnezia-wg/).

- Multi-arch: `amd64` и `arm64`
- Один и тот же контейнер работает как **клиент**, так и **сервер**: роль определяется содержимым конфига

## Как это работает

При старте контейнер поднимает интерфейсы для всех `.conf` файлов из директории `configs` (внутри контейнера `/etc/amnezia/amneziawg`) через `awg-quick`.

Готовые шаблоны конфигов с плейсхолдерами: [`examples/client.conf`](examples/client.conf) и [`examples/server.conf`](examples/server.conf). Скопируйте нужный в `configs/` под именем интерфейса (например `wg0.conf`) и подставьте свои ключи.

Возможны два режима работы:

- `Userspace` (по умолчанию): модуль ядра на хосте не нужен, используется реализация `amneziawg-go` и требуется проброс устройства `/dev/net/tun`.
- `Kernel`: если на хосте установлен модуль ядра `amneziawg`, используется он. Проброс `/dev/net/tun` в этом случае не обязателен, но не будет мешать работе контейнера.

## Генерация ключей и пиры

У каждой стороны (сервер и каждый клиент) своя пара ключей. Команда генерирует одну пару - запускайте её по разу на каждую сторону:

```bash
docker run --rm --entrypoint sh vernette/amneziawg:v1.0.20260223 -c \
  'priv=$(awg genkey); printf "PrivateKey = %s\nPublicKey = %s\n" "$priv" "$(echo "$priv" | awg pubkey)"'
```

Правило раскладки: **свой приватный ключ - в `[Interface]`, публичный ключ пира - в `[Peer]`**.

### Сервер

Сгенерируйте пару сервера и заполните [`examples/server.conf`](examples/server.conf):

```ini
[Interface]
PrivateKey = <SERVER_PRIVATE_KEY>   # приватный ключ сервера
# ...
[Peer]
PublicKey = <CLIENT_PUBLIC_KEY>     # публичный ключ клиента (из шага 2)
```

### Клиент

Сгенерируйте пару клиента и заполните [`examples/client.conf`](examples/client.conf):

```ini
[Interface]
PrivateKey = <CLIENT_PRIVATE_KEY>   # приватный ключ клиента
# ...
[Peer]
PublicKey = <SERVER_PUBLIC_KEY>     # публичный ключ сервера (из шага 1)
Endpoint = your.server.example:51820
```

Итог:

| Конфиг        | `[Interface] PrivateKey` | `[Peer] PublicKey` |
| ------------- | ------------------------ | ------------------ |
| `server.conf` | приватный сервера        | публичный клиента  |
| `client.conf` | приватный клиента        | публичный сервера  |

### Добавление новых клиентов

Для каждого нового клиента:

1. Сгенерируйте отдельную пару ключей.
2. В серверный конфиг добавьте **новый** блок `[Peer]` с публичным ключом клиента и уникальным адресом в `AllowedIPs`:

   ```ini
   [Peer]
   PublicKey = <CLIENT2_PUBLIC_KEY>
   AllowedIPs = 10.10.0.3/32
   ```

3. В конфиг нового клиента впишите его приватный ключ и публичный ключ сервера (как в шаге 2), задав свой `Address` (`10.10.0.3/24`).

### Отдельные команды

```bash
# приватный ключ
docker run --rm --entrypoint awg vernette/amneziawg:v1.0.20260223 genkey

# публичный ключ из приватного
echo <PRIVATE_KEY> | docker run --rm -i --entrypoint awg vernette/amneziawg:v1.0.20260223 pubkey

# предварительный общий ключ (PSK, опционально)
docker run --rm --entrypoint awg vernette/amneziawg:v1.0.20260223 genpsk
```

## Параметры AmneziaWG

В конфиге клиента можно использовать `Jc`, `Jmin`, `Jmax` и, например, `I1` - junk-настройки клиента: добавляют мусор в handshake и нужны только на стороне клиента. Совпадение с сервером не требуется, их можно применять даже к обычному WireGuard серверу. Остальные параметры обязаны совпадать с параметрами сервера.

Более подробно про параметры AmneziaWG в [документации](https://docs.amnezia.org/ru/documentation/amnezia-wg/#%D0%BF%D0%B0%D1%80%D0%B0%D0%BC%D0%B5%D1%82%D1%80%D1%8B-%D0%BA%D0%BE%D0%BD%D1%84%D0%B8%D0%B3%D1%83%D1%80%D0%B0%D1%86%D0%B8%D0%B8) и [статье](https://habr.com/ru/companies/amnezia/articles/1014636/).

## Работа в режиме клиента

1. Создайте директорию `configs`:

   ```bash
   mkdir configs
   ```

2. Поместите конфиг в `./configs/wg0.conf` (имя файла = имя интерфейса), указав необходимые параметры AmneziaWG (`Jc`, `Jmin`, `Jmax`, `I1`, etc).
3. Запустите контейнер:

   ```bash
   docker compose up -d
   ```

Базовый `compose.yaml` для клиента в userspace-режиме:

```yaml
services:
  amneziawg:
    image: vernette/amneziawg:v1.0.20260223
    container_name: amneziawg-client
    restart: always
    volumes:
      - ./configs:/etc/amnezia/amneziawg:ro
    devices:
      - /dev/net/tun:/dev/net/tun # только userspace-режим
    cap_add:
      - NET_ADMIN
```

- `volumes`: каталог с конфигами (монтируется только для чтения)
- `devices`: проброс `/dev/net/tun`, нужен только в userspace-режиме
- По умолчанию интерфейс доступен только внутри контейнера. При необходимости раскомментируйте одну из опций `network_mode` в `compose.yaml`:
  - `network_mode: "host"`: контейнер будет использовать сетевой стек хоста и интерфейс будет доступен в системе хоста
  - `network_mode: "service:some_service"`: контейнер будет использовать namespace указанного контейнера и второй сможет использовать интерфейс первого будто это его собственный интерфейс

### Split-tunnel vs full-tunnel

Поведение зависит от `AllowedIPs` в `[Peer]` клиентского конфига.

- Split-tunnel: `AllowedIPs` перечисляет только нужные сети (например `10.10.0.0/24`). В туннель идёт лишь трафик к этим адресам, остальное - напрямую. Базовый `compose.yaml` выше работает как есть.
- Full-tunnel: `AllowedIPs = 0.0.0.0/0, ::/0`, весь трафик в туннель. `awg-quick` добавляет policy-routing (`fwmark`, отдельная таблица маршрутизации) и пишет `net.ipv4.conf.all.src_valid_mark=1`. Этот sysctl нужно предзадать на уровне Docker:

  ```yaml
  services:
    amneziawg:
      image: vernette/amneziawg:v1.0.20260223
      container_name: amneziawg-client
      restart: always
      volumes:
        - ./configs:/etc/amnezia/amneziawg:ro
      devices:
        - /dev/net/tun:/dev/net/tun # только userspace-режим
      cap_add:
        - NET_ADMIN
      sysctls:
        - net.ipv4.conf.all.src_valid_mark=1 # нужно для full-tunnel
  ```

> [!NOTE]
> Альтернатива - `Table = off` в `[Interface]` клиентского конфига. Полностью отключает авто-маршрутизацию `awg-quick`. Подходит, когда маршрутизацией управляете сами или делите интерфейс через `network_mode: "service:..."` для одного приложения. При этом full-tunnel сам не заработает - маршруты добавляете вручную (`PostUp` / `ip route`).

> [!WARNING]
> Режим `network_mode: host`. Блок `sysctls` Docker **отклонит** - namespaced `net.*` sysctls при host-сети задавать нельзя (`src_valid_mark` берётся с хоста). Дополнительно: host + full-tunnel (`0.0.0.0/0`) **без** `Table = off` ставит policy-routing на самом хосте и захватывает его дефолтный маршрут - весь egress хоста уйдёт в VPN, а удалённая SSH-сессия (не из LAN) оборвётся. В bridge-режиме всё это изолировано в namespace контейнера и хосту не вредит.

## Работа в режиме сервера

Для сервера нужно пробросить UDP-порт из `ListenPort` и включить форвардинг. NAT и маршрутизация задаются через `PostUp`/`PostDown` в `.conf` - точно так же, как в обычном WireGuard-сервере (`awg-quick` - форк `wg-quick`). Образ уже содержит `iptables` и `ip6tables`.

```yaml
services:
  amneziawg:
    image: vernette/amneziawg:v1.0.20260223
    container_name: amneziawg-server
    restart: always
    volumes:
      - ./configs:/etc/amnezia/amneziawg:ro
    ports:
      - "51820:51820/udp" # должен совпадать с ListenPort в .conf
    devices:
      - /dev/net/tun:/dev/net/tun # только userspace-режим
    cap_add:
      - NET_ADMIN
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv6.conf.all.forwarding=1 # только если нужен IPv6
```

Пример NAT в серверном `.conf`:

```ini
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
```

`eth0` - исходящий интерфейс внутри контейнера (в дефолтной bridge-сети чаще всего именно он). Отдельные правила `FORWARD` не нужны: в собственном сетевом namespace контейнера политика `FORWARD` по умолчанию `ACCEPT`, достаточно `MASQUERADE`.

Для IPv6 NAT по аналогии (если нужен):

```ini
PostUp = ip6tables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = ip6tables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
```

> [!NOTE]
> Режим `network_mode: host`. Конфигурация выше рассчитана на bridge-сеть.
> Если запускать контейнер с `network_mode: host`, есть отличия:
>
> - Блок `sysctls` Docker **отклонит** - задавать namespaced `net.*` sysctls
>   при host-сети нельзя. Форвардинг нужно включать на самом хосте
>   (например, в `/etc/sysctl.d/`); на хосте с Docker `net.ipv4.ip_forward`
>   обычно уже `= 1`.
> - Проброс `ports` не нужен - контейнер слушает `ListenPort` прямо на хосте.
> - Правила из `PostUp`/`PostDown` пишутся в firewall **хоста**, а не в
>   изолированный namespace, и смешиваются с правилами хоста (включая
>   цепочки Docker). Имя egress-интерфейса в `MASQUERADE` тоже будет хостовым
>   (часто не `eth0`).
> - `/dev/net/tun` и `NET_ADMIN` по-прежнему нужны для userspace-режима.

## Модуль ядра (kernel-режим)

Userspace-режим работает из коробки, но модуль ядра даёт более высокую производительность и меньшую нагрузку.

Установить его можно из официального репозитория [amneziawg-linux-kernel-module](https://github.com/amnezia-vpn/amneziawg-linux-kernel-module) для своего дистрибутива:

1. Установите модуль на **хост** - через DKMS из готовых пакетов для вашего дистрибутива или сборкой из исходников (инструкции в README репозитория модуля). Пример для Debian:

   ```bash
   sudo apt install -y software-properties-common python3-launchpadlib gnupg2 linux-headers-$(uname -r)
   sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 57290828
   echo "deb https://ppa.launchpadcontent.net/amnezia/ppa/ubuntu focal main" | sudo tee -a /etc/apt/sources.list
   echo "deb-src https://ppa.launchpadcontent.net/amnezia/ppa/ubuntu focal main" | sudo tee -a /etc/apt/sources.list
   sudo apt update
   sudo apt install -y amneziawg
   ```

2. Загрузите модуль:

   ```bash
   sudo modprobe amneziawg
   ```

3. После этого из `compose.yaml` можно убрать блок `devices: /dev/net/tun` - в kernel-режиме он не требуется. Если контейнер уже работал в userspace-режиме, необходимо перезапустить его:

   ```bash
   docker compose down
   docker compose up -d
   ```

## Теги образа

- `vernette/amneziawg:latest`: последний собранный образ
- `vernette/amneziawg:<версия>`: привязка к тегу [amneziawg-tools](https://github.com/amnezia-vpn/amneziawg-tools)

## Ссылки

- [Документация AmneziaWG](https://docs.amnezia.org/ru/documentation/amnezia-wg/)
- [amneziawg-go](https://github.com/amnezia-vpn/amneziawg-go) - userspace-реализация
- [amneziawg-tools](https://github.com/amnezia-vpn/amneziawg-tools) - `awg` / `awg-quick`
- [amneziawg-linux-kernel-module](https://github.com/amnezia-vpn/amneziawg-linux-kernel-module) - модуль ядра

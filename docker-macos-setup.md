# macOS Docker Setup for iOS Development

## Uyarı
Bu yöntem Apple'ın lisans koşullarına aykırı olabilir. Sadece eğitim amaçlı kullanın.

## Gereksinimler
- Docker
- Yeterli RAM (en az 8GB)
- SSD disk

## Kurulum
```bash
# macOS Docker image'ı çekin
docker pull sickcodes/docker-osx:auto

# macOS container'ı çalıştırın
docker run -it \
  --device /dev/kvm \
  -p 50922:10022 \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -e "DISPLAY=${DISPLAY:-:0.0}" \
  sickcodes/docker-osx:auto
```

## Flutter iOS Development
Container içinde:
```bash
# Xcode kurulumu
# Flutter kurulumu
# iOS simulator kurulumu
```

## Not
Bu yöntem yasal olmayabilir ve performans sorunları yaşayabilirsiniz.

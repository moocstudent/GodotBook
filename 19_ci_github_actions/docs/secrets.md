# GitHub Secrets 清单

`Settings → Secrets and variables → Actions → New repository secret`,逐条添加。

## itch.io 发布

| Secret 名 | 值 |
|----------|----|
| `BUTLER_API_KEY` | https://itch.io/user/settings/api-keys 生成 |

## iOS 签名

| Secret 名 | 值 |
|----------|----|
| `IOS_P12_BASE64` | `.p12` 证书 base64:`base64 -i cert.p12 \| pbcopy` |
| `IOS_P12_PASSWORD` | 导出 .p12 时设的密码 |
| `IOS_PROVISION_BASE64` | `base64 -i profile.mobileprovision \| pbcopy` |
| `IOS_TEAM_ID` | Apple Developer Membership 页 10 位 |

## Android 签名(如要 release)

| Secret 名 | 值 |
|----------|----|
| `ANDROID_KEYSTORE_BASE64` | `base64 -i release.keystore \| pbcopy` |
| `ANDROID_KEY_ALIAS` | 创建时的 alias |
| `ANDROID_KEY_PASSWORD` | key 密码 |
| `ANDROID_STORE_PASSWORD` | keystore 密码 |

workflow 里用法:
```yaml
- name: Decode keystore
  run: |
    echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 -d > release.keystore

- name: Patch export_presets.cfg
  run: |
    sed -i "s|keystore/release=\"\"|keystore/release=\"$(pwd)/release.keystore\"|" export_presets.cfg
    sed -i "s|keystore/release_user=\"\"|keystore/release_user=\"${{ secrets.ANDROID_KEY_ALIAS }}\"|" export_presets.cfg
    sed -i "s|keystore/release_password=\"\"|keystore/release_password=\"${{ secrets.ANDROID_KEY_PASSWORD }}\"|" export_presets.cfg
```

## Steam 上传(steamcmd)

| Secret 名 | 值 |
|----------|----|
| `STEAM_USERNAME` | 你的 Steam 账号 |
| `STEAM_CONFIG_VDF` | 一次性手动登录 steamcmd 后从 `~/Steam/config/config.vdf` 取(避免 2FA 拦) |
| `STEAM_APPID` | App 后台数字 ID |
| `STEAM_DEPOT_*` | 各 depot ID |

## 验证

`Actions` tab → 选某个 workflow → `Re-run jobs`,看运行起来正常。

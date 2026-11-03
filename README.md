<p align="center">
  <img src="Debian-Pure-Blend/sucesu/wallpaper.jpg" alt="SUCESU PR - Linux Edu" width="600">
</p>

# SUCESU Linux Edu

ISO personalizada do **Debian Edu 13 (Trixie)** para as máquinas do projeto **SUCESU PR**.
Ela é a imagem oficial do Debian Edu com três ajustes: o wallpaper do projeto (área de trabalho e tela de login) e duas ferramentas de preparação de discos no menu de boot.

- **Projetos:** Click Escolas Sociais
- **Requisitos:** zerar o HD e instalar
- **Legado:** reaproveitamento de máquinas doadas
- **Benefícios:** ESG, SUCESU e Lions

---

## O que a imagem traz

| Item | Descrição |
|---|---|
| Wallpaper | Aplicado na área de trabalho (Xfce) no primeiro login de cada usuário e na tela de login (LightDM) |
| Instalação normal | Entradas originais do Debian Edu (por exemplo, *Graphical install*), com o wallpaper |
| **Sucesu: APAGAR DISCOS** | Modo texto. Mostra a máquina (modelo, CPU, memória) e os discos, pede confirmação (`SIM`), zera todos os discos internos mostrando o progresso, confere amostras e desliga. **Não instala nada.** |
| **Sucesu: VERIFICAR DISCOS** | Modo texto. Só lê os discos e informa se estão zerados. Não altera nada. |

Tudo o mais é o Debian Edu padrão.

---

## Estrutura do repositório

```
.
├── Debian-Pure-Blend/
│   ├── build.sh              # gera a ISO
│   └── sucesu/
│       ├── wallpaper.jpg     # imagem (4K) usada no desktop e no login
│       ├── wallpaper.sh      # aplica o wallpaper no primeiro login (Xfce/KDE/GNOME)
│       ├── login.sh          # configura o wallpaper da tela de login (LightDM)
│       ├── comum.sh          # funções comuns das ferramentas de disco
│       ├── apagar.sh         # menu "APAGAR DISCOS"
│       └── verificar.sh      # menu "VERIFICAR DISCOS"
├── wallpaper/                # arte original do wallpaper
├── LICENSE                   # GPL-3.0
└── README.md
```

O `build.sh` também gera, a cada execução, os arquivos de preseed (`sucesu.cfg`, `apagar.cfg`, `verificar.cfg`) e o `wallpaper.desktop`. Não precisam ser versionados.

---

## Gerar a imagem

### Requisitos

- Linux (Debian/Ubuntu) com o `xorriso`:
  ```bash
  sudo apt install xorriso
  ```
- A ISO oficial do Debian Edu 13 (use a mesma versão em que o projeto foi testado: **13.7.0, netinst**), baixada em <https://www.debian.org/devel/debian-edu/>. Confira o SHA256 com o arquivo `SHA256SUMS` publicado no site:
  ```bash
  sha256sum debian-edu-13.7.0-amd64-netinst.iso
  ```
- Espaço livre em disco: pelo menos o tamanho da ISO original (cerca de 1 GB na netinst; cerca de 17 GB na versão completa).

### Passos

```bash
git clone https://github.com/ambientelivre/sucesu-linux-edu.git
cd sucesu-linux-edu/Debian-Pure-Blend

# coloque a ISO original nesta pasta e rode:
./build.sh                                   # netinst (nome padrão debian-edu-13.7.0-amd64-netinst.iso)
./build.sh debian-edu-13.7.0-amd64-XXXX.iso  # outra imagem, por exemplo a completa (use o nome real do arquivo)
```

A ISO nova aparece na mesma pasta, com o nome `sucesu-pr-<nome-da-iso-original>-<data>.iso`. Ao final, o script mostra:

```
Pronto: .../sucesu-pr-debian-edu-13.7.0-amd64-netinst-AAAA.MM.DD.iso
Entradas APAGAR/VERIFICAR (modo texto) -> BIOS: SIM | UEFI: SIM
```

Se aparecer `UEFI: NAO` ou uma linha com `!!!`, as entradas de menu para UEFI não foram criadas. Veja a tabela abaixo.

### Códigos de saída do `build.sh`

| Código | Significado |
|---|---|
| 1 | Falta a ISO original, um arquivo em `sucesu/` ou o `xorriso` |
| 2 | O menu de boot da ISO já usa `preseed/file`. O script não sobrescreve |
| 3 | Nenhuma linha de boot foi alterada: o formato dos menus é diferente do esperado |
| 4 | O `xorriso` falhou ao remontar a ISO (a ISO incompleta é removida) |
| 5 | Não foi possível criar as entradas APAGAR/VERIFICAR (formato inesperado do menu) |

Se a ISO original for outra versão do Debian Edu, o formato dos menus pode mudar. Teste sempre numa VM antes de gravar o pendrive.

### Testar numa VM (VirtualBox)

1. Crie uma VM Linux/Debian de 64 bits, com 4 GB ou mais de RAM e disco de 40 GB ou mais.
2. Ao selecionar a ISO, marque **Skip Unattended Installation**, ou o VirtualBox injeta um preseed próprio e atrapalha o teste.
3. Teste em **BIOS** e em **UEFI** (Sistema → *Habilitar EFI*), em VMs separadas.

---

## Gravar no pendrive

Use um pendrive de **2 GB ou mais** para a netinst (**32 GB ou mais**, USB 3.0, para a versão completa). **Todos os dados do pendrive serão apagados.**

### Linux

```bash
lsblk                                   # identifique o pendrive (ex.: /dev/sdb). CONFIRA o dispositivo
sudo dd if=sucesu-pr-debian-edu-13.7.0-amd64-netinst-AAAA.MM.DD.iso of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

Troque `sdX` pelo dispositivo do pendrive, não por uma partição (`sdb`, e não `sdb1`). Gravar no disco errado apaga o disco errado.

### Windows

Use o **Rufus** e, quando ele perguntar, escolha **Gravar no modo Imagem DD** (e não o modo ISO). O balenaEtcher também funciona.

---

## Preparar os discos (máquinas usadas ou doadas)

Se a máquina já teve outro dono, apague o disco **antes** de instalar. O particionamento do instalador não apaga os dados de verdade: só recria as partições, e os dados antigos continuam recuperáveis.

1. Dê boot pelo pendrive e escolha **Sucesu: APAGAR DISCOS (so apaga, NAO instala)**.
2. A tela em modo texto mostra o modelo da máquina, a CPU, a memória e a lista de discos que serão apagados (tamanho, tipo e modelo).
3. Confira a lista e digite **`SIM`** + ENTER. Qualquer outra resposta cancela, e nada é apagado.
4. Acompanhe o progresso. Todos os discos internos são apagados em paralelo, e o pendrive de instalação nunca é tocado.
5. No final, o script confere amostras do disco e mostra **APAGAMENTO CONCLUIDO - OK**. ENTER desliga a máquina.

Tempo estimado: um HDD de 1 TB leva de 2 a 3 horas. Várias máquinas podem ser apagadas ao mesmo tempo, cada uma com seu pendrive.

Para conferir depois, use **Sucesu: VERIFICAR DISCOS**, que só lê os discos e mostra se estão zerados.

**Limitações**
- O apagamento é uma passada de zeros, suficiente para HDD comum. Em **SSD/NVMe** ela não garante o apagamento de áreas reservadas do controlador. Nesses casos use o *secure erase* do fabricante ou a destruição física.
- O script não gera comprovante de descarte. Se precisar de um relatório por disco, use uma ferramenta própria (por exemplo, o ShredOS com `nwipe`).
- A verificação lê amostras do disco (início, fim e pontos intermediários), não o disco inteiro.
- Para testar sem escrever nada, acrescente `sucesu_dryrun` à linha de boot (tecla `Tab` no menu BIOS, `e` no UEFI).

---

## Instalar o desktop

Dê boot pelo pendrive e use a entrada de instalação do Debian Edu (por exemplo, **Graphical install**). A instalação precisa de internet, pois a netinst baixa os pacotes. Em redes com várias máquinas, um `apt-cacher-ng` na rede local acelera bastante.

### Perfil

Escolha o perfil do Debian Edu conforme o ambiente da escola (por exemplo, *Standalone* para uma máquina independente, ou *Workstation* para máquina ligada a um servidor principal).

### Particionamento (obrigatório)

O disco deve ser **particionado por completo, com LVM e sem criptografia**.

Na pergunta *"Realmente usar a ferramenta de particionamento automático?"*, responda **Não** e use o particionamento guiado do Debian:

1. Método: **Guiado - usar o disco inteiro e configurar o LVM**. Não escolha a opção *criptografado*.
2. Selecione o disco da máquina (não o pendrive).
3. Esquema: **Todos os arquivos em uma partição**.
4. Tamanho do grupo de volumes: aceite o padrão (máximo), para usar o disco inteiro.
5. Confirme a gravação das alterações.

Por que não usar o particionamento automático do Debian Edu: ele cria `/` e `/home` pequenos (16 GB e 30 GB num disco de 1 TB) e deixa o resto livre no LVM, esperando que um administrador aumente as partições depois. Os usuários finais destas máquinas não farão isso.

### Usuário e senhas

| Item | Valor |
|---|---|
| Usuário | **`sucesu`** (obrigatório) |
| Senha do usuário | definida caso a caso, no instalador |
| Senha do root | definida caso a caso, no instalador |

Para **avaliação e testes**, o padrão é usuário **`sucesu`**, senha **`sucesu`** (e a mesma senha para o root). **Não use esse padrão em máquinas em produção.** Defina senhas diferentes para cada máquina ou lote e registre onde estão guardadas.

### Primeiro boot

1. Retire o pendrive. Se a BIOS iniciar pelo USB antes do disco, ajuste a ordem de boot, ou a máquina volta ao menu do instalador (e alguém pode escolher APAGAR DISCOS sem querer).
2. A tela de login já aparece com o wallpaper do projeto. Entre com o usuário `sucesu`.
3. O wallpaper da área de trabalho é aplicado uma vez no primeiro login de cada usuário. Se o usuário trocar depois, o sistema não sobrescreve. O registro fica em `~/.cache/sucesu-wallpaper.log`.

---

## Estado do projeto e limitações conhecidas

- **Versão inicial.** Testada em VirtualBox. Recomenda-se um piloto em 1 ou 2 máquinas reais (de preferência um notebook e um desktop) antes de instalar em série.
- **Monitores.** O wallpaper é 16:9 (3840x2160). Em monitores 4:3 e 5:4 as laterais são cortadas. As logos ficam dentro da área segura e a caixa de login fica no canto superior esquerdo para não cobrir a imagem.
- **Home em rede (perfil Workstation).** O wallpaper é aplicado uma vez por usuário, e o marcador fica no home do usuário. Em máquinas com home em rede, isso não foi testado.
- **Atualizações.** A netinst instala os pacotes mais recentes do espelho; a ISO completa traz os pacotes da data do lançamento. Rode `apt upgrade` depois de instalar.

---

## Licença

[GPL-3.0](LICENSE)

## Créditos

SUCESU PR · [Ambiente Livre](https://ambientelivre.com.br) · GUCIO Paraná · [Hackarandu](https://www.hackarandu.com) · [Debian Edu / Skolelinux](https://www.debian.org/devel/debian-edu/)

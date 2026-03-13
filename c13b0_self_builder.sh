#!/usr/bin/env bash
# 🧱 C13B0 SELF BUILDER
# Creates c13b0_generator.sh and build_new_cart.sh in ~/c13b0_machine
# Compatible with Termux and standard Linux

set -euo pipefail

echo "🧱 C13B0 SELF BUILDER INITIALIZING"

BASE=~/c13b0_machine
mkdir -p "$BASE"
cd "$BASE"

echo "⭐ Creating core generator..."

cat << 'EOF' > c13b0_generator.sh
#!/usr/bin/env bash

echo "🍄 C13B0 GENERATOR ACTIVE"

NAME=$1

if [ -z "$NAME" ]; then
  echo "Usage: ./c13b0_generator.sh CART_NAME"
  exit 1
fi

mkdir -p "$NAME"
cd "$NAME"

echo "⭐ Building new cartridge $NAME"

cat << 'INNER' > run.sh
#!/usr/bin/env bash
echo "💲 Cartridge running"
echo "Cart: $(pwd)"
INNER

chmod +x run.sh

echo "👑 Cartridge created: $NAME"
EOF

chmod +x c13b0_generator.sh

echo "⭐ Creating auto builder..."

cat << 'EOF' > build_new_cart.sh
#!/usr/bin/env bash

echo "🧱 BUILDING CART"

read -rp "Cart Name: " CART

if [ -z "$CART" ]; then
  echo "❌ Cart name required"
  exit 1
fi

./c13b0_generator.sh "$CART"

echo "🍄 Done"
EOF

chmod +x build_new_cart.sh

echo ""
echo "💲 MACHINE READY"
echo ""
echo "Use:"
echo "  cd $BASE"
echo "  ./build_new_cart.sh"

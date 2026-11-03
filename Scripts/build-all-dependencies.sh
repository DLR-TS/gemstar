#!/usr/bin/env bash
# Copyright (c) 2026 DLR e.V.
#
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0

set -euo pipefail

GEMSTAR_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. ${GEMSTAR_ROOT_DIR}/Plugins/gemstar_interfaces/Scripts/build-dependencies.sh
. ${GEMSTAR_ROOT_DIR}/Plugins/GameFeatures/ue_esmini_feature/Scripts/build-dependencies.sh
. ${GEMSTAR_ROOT_DIR}/Plugins/GameFeatures/ue_fmi_feature/Scripts/build-dependencies.sh
. ${GEMSTAR_ROOT_DIR}/Plugins/GameFeatures/ue_sumo_feature/Scripts/build-dependencies.sh


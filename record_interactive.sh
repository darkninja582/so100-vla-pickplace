#!/bin/bash

source ~/lerobot_env/bin/activate
cd ~/lerobot

TOTAL=150
CURRENT=$(python -c "import json; print(json.load(open('$HOME/.cache/huggingface/lerobot/so100_pick_place/meta/info.json'))['total_episodes'])" 2>/dev/null || echo 0)
EPISODE=$((CURRENT+1))
DATASET_PATH="$HOME/.cache/huggingface/lerobot/so100_pick_place"

declare -A ZONES
ZONES[TL]="0-16.6cm right,  16-23cm far"
ZONES[TC]="16.6-33.3cm right, 16-23cm far"
ZONES[TR]="33.3-50cm right, 16-23cm far"
ZONES[ML]="0-16.6cm right,  23-30cm far"
ZONES[MC]="16.6-33.3cm right, 23-30cm far"
ZONES[MR]="33.3-50cm right, 23-30cm far"
ZONES[BL]="0-16.6cm right,  30-37cm far"
ZONES[BC]="16.6-33.3cm right, 30-37cm far"
ZONES[BR]="33.3-50cm right, 30-37cm far"

OBJECT_ZONES=(TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR)
TRAY_ZONES=(BR TL MC TR BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR BC MC BL MR TL BR TC ML TR)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   🤖 SO-100 Pick & Place Recording Script"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📷 Camera 1: Arducam → /dev/video2"
echo "  📷 Camera 2: SK Wrist → /dev/video4"
echo "  📦 Dataset: $DATASET_PATH"
echo "  🎯 Total Episodes: $TOTAL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

while [ $EPISODE -le $TOTAL ]; do
    OZONE=${OBJECT_ZONES[$((EPISODE-1))]}
    TZONE=${TRAY_ZONES[$((EPISODE-1))]}
    OZONE_DESC=${ZONES[$OZONE]}
    TZONE_DESC=${ZONES[$TZONE]}

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📍 Episode $EPISODE / $TOTAL"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📦 OBJECT → Zone [$OZONE]: $OZONE_DESC"
    echo "  🗑️  TRAY   → Zone [$TZONE]: $TZONE_DESC"
    echo ""
    echo "  ┌──────────┬──────────┬──────────┐"
    echo "  │    TL    │    TC    │    TR    │"
    echo "  ├──────────┼──────────┼──────────┤"
    echo "  │    ML    │    MC    │    MR    │"
    echo "  ├──────────┼──────────┼──────────┤"
    echo "  │    BL    │    BC    │    BR    │"
    echo "  └──────────┴──────────┴──────────┘"
    echo "      🤖 ROBOT BASE"
    echo ""
    echo "  1. Place OBJECT at [$OZONE]"
    echo "  2. Place TRAY   at [$TZONE]"
    echo "  3. Move arms to REST position"
    echo "  4. Power cycle if unresponsive"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    read -p "  ENTER to record | Q to quit: " choice

    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
        echo ""
        echo "⛔ Stopped at episode $EPISODE"
        echo "✅ Total saved: $((EPISODE-1))"
        break
    fi

    if [ -f "$DATASET_PATH/meta/tasks.parquet" ]; then
        RESUME_FLAG="true"
    else
        RESUME_FLAG="false"
    fi

    python ~/lerobot/src/lerobot/scripts/lerobot_record.py \
        --robot.type=so100_follower \
        --robot.port=/dev/ttyACM0 \
        --robot.id=follower \
        --robot.max_relative_target=10 \
        --robot.cameras='{"workspace":{"type":"opencv","index_or_path":"/dev/v4l/by-id/usb-Arducam_Technology_Co.__Ltd._Arducam_IMX477_HQ_Camera_UC517-video-index0","width":640,"height":480,"fps":30,"warmup_s":10},"wrist":{"type":"opencv","index_or_path":"/dev/v4l/by-id/usb-webcamvendor_SK_series1_20220325JWGD2093-video-index0","width":640,"height":480,"fps":30,"fourcc":"MJPG","warmup_s":5}}' \
        --teleop.type=so100_leader \
        --teleop.port=/dev/ttyACM0 \
        --teleop.id=leader \
        --dataset.repo_id=so100_pick_place \
        --dataset.root=$DATASET_PATH \
        --dataset.single_task="Pick and place object" \
        --dataset.num_episodes=1 \
        --dataset.episode_time_s=30 \
        --dataset.reset_time_s=5 \
        --dataset.push_to_hub=false \
        --dataset.fps=15 \
        --resume=$RESUME_FLAG \
        --display_data=true \

    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ Episode $EPISODE recorded!"
        echo "   Object:[$OZONE] → Tray:[$TZONE]"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Was this episode GOOD or BAD?"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        read -p "  G=Good(keep) | R=Redo(delete+retry) | Q=quit: " quality

        if [[ "$quality" == "q" || "$quality" == "Q" ]]; then
            echo "⛔ Stopped. Total saved: $EPISODE"
            break

        elif [[ "$quality" == "r" || "$quality" == "R" ]]; then
            echo ""
            echo "🗑️  Deleting bad episode $EPISODE and redoing..."

            # Delete the last saved episode using lerobot edit
            python ~/lerobot/src/lerobot/scripts/lerobot_edit_dataset.py \
                --repo-id=so100_pick_place \
                --root=$DATASET_PATH \
                --task=delete_episode \
                --episode-index=$((EPISODE-1)) 2>/dev/null || \
            python -c "
import json, os, shutil
from pathlib import Path

dataset_path = '$DATASET_PATH'
meta_path = Path(dataset_path) / 'meta'

# Read current episode count
info_file = meta_path / 'info.json'
with open(info_file) as f:
    info = json.load(f)

last_ep = info['total_episodes'] - 1
print(f'Deleting episode {last_ep}...')

# Delete parquet file
parquet = Path(dataset_path) / f'data/chunk-000/file-{last_ep:03d}.parquet'
if parquet.exists():
    parquet.unlink()
    print(f'Deleted: {parquet}')

# Delete video files
for cam in ['workspace', 'wrist']:
    video = Path(dataset_path) / f'videos/observation.images.{cam}/chunk-000/file-{last_ep:03d}.mp4'
    if video.exists():
        video.unlink()
        print(f'Deleted: {video}')

# Update info.json
info['total_episodes'] -= 1
info['total_frames'] -= info.get('episode_length', 450)
with open(info_file, 'w') as f:
    json.dump(info, f, indent=4)

print(f'✅ Episode {last_ep} deleted! Total episodes: {info[\"total_episodes\"]}')
"
            echo ""
            echo "🔄 Retrying episode $EPISODE..."
            echo "  Reset object and tray to same positions:"
            echo "  📦 OBJECT → [$OZONE]"
            echo "  🗑️  TRAY   → [$TZONE]"
            read -p "  ENTER when ready to re-record: " _

        else
            echo "✅ Episode $EPISODE kept!"
            EPISODE=$((EPISODE + 1))
        fi

    else
        echo ""
        echo "❌ Episode $EPISODE FAILED!"
        echo "👉 Power cycle arms, move joints to middle"
        read -p "  ENTER to retry | Q to skip: " retry
        if [[ "$retry" == "q" || "$retry" == "Q" ]]; then
            EPISODE=$((EPISODE + 1))
        fi
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🎉 Recording Complete!"
echo "  Total Episodes: $((EPISODE-1))"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# SO-100 VLA Pick & Place Project

A complete guide to setting up a Vision-Language-Action (VLA) system using SO-100 robot arms with LeRobot framework.

## Hardware Setup
- SO-100 Robot Arms x2 (Leader + Follower)
- Feetech STS3215 Servos (Leader: IDs 7-12, Follower: IDs 1-6)
- Arducam IMX477 HQ Camera (workspace/top view)
- SK series1 Camera (wrist view)
- Single USB Control Board (/dev/ttyACM0)
- External Power Supply (5V-7.4V @ 5A+)

## Software Stack
- Ubuntu 22.04
- Python 3.12
- LeRobot v0.5.2 (HuggingFace)
- ACT Policy (Action Chunking with Transformers)
- PyTorch 2.11.0 + CUDA

## Installation
```bash
git clone https://github.com/huggingface/lerobot.git
cd lerobot
python3.12 -m venv lerobot_env
source lerobot_env/bin/activate
pip install -e ".[feetech]"
pip install 'lerobot[training]'
pip install 'lerobot[dataset]'
pip install flask av pynput
```

## Patches Required
Copy files from patches/ folder to their respective locations:
- patches/motors_bus.py → src/lerobot/motors/motors_bus.py
- patches/so_leader.py → src/lerobot/teleoperators/so_leader/so_leader.py
- patches/so_follower.py → src/lerobot/robots/so_follower/so_follower.py
- patches/video_utils.py → src/lerobot/datasets/video_utils.py
- patches/lerobot_dataset.py → src/lerobot/datasets/lerobot_dataset.py
- patches/utils.py → src/lerobot/datasets/utils.py

## Calibration
```bash
# Leader arm (IDs 7-12)
python src/lerobot/scripts/lerobot_calibrate.py \
    --teleop.type=so100_leader \
    --teleop.port=/dev/ttyACM0 \
    --teleop.id=leader

# Follower arm (IDs 1-6)
python src/lerobot/scripts/lerobot_calibrate.py \
    --robot.type=so100_follower \
    --robot.port=/dev/ttyACM0 \
    --robot.id=follower
```

## Teleoperation
```bash
python src/lerobot/scripts/lerobot_teleoperate.py \
    --teleop.type=so100_leader \
    --teleop.port=/dev/ttyACM0 \
    --teleop.id=leader \
    --robot.type=so100_follower \
    --robot.port=/dev/ttyACM0 \
    --robot.id=follower \
    --fps=10
```

## Recording Demonstrations
```bash
./record_interactive.sh
```

## Camera Preview
```bash
python visualize_recording.py
# Open http://localhost:5000
```

## Training
```bash
python -m lerobot.scripts.lerobot_train \
    --policy.type=act \
    --dataset.repo_id=so100_pick_place \
    --dataset.root=$HOME/.cache/huggingface/lerobot/so100_pick_place \
    --dataset.video_backend=pyav \
    --output_dir=outputs/train/so100_act \
    --steps=80000 \
    --batch_size=8 \
    --save_freq=5000 \
    --wandb.enable=false \
    --policy.push_to_hub=false \
    --policy.repo_id=so100_act_policy
```

## Inference
```bash
python -m lerobot.scripts.lerobot_rollout \
    --robot.type=so100_follower \
    --robot.port=/dev/ttyACM0 \
    --robot.id=follower \
    --robot.max_relative_target=10 \
    --robot.cameras='{"workspace":{"type":"opencv","index_or_path":"/dev/v4l/by-id/usb-Arducam_Technology_Co.__Ltd._Arducam_IMX477_HQ_Camera_UC517-video-index0","width":640,"height":480,"fps":15,"warmup_s":10},"wrist":{"type":"opencv","index_or_path":"/dev/v4l/by-id/usb-webcamvendor_SK_series1_20220325JWGD2093-video-index0","width":640,"height":480,"fps":30,"fourcc":"MJPG","warmup_s":5}}' \
    --policy.type=act \
    --policy.pretrained_path=outputs/train/so100_act/checkpoints/last/pretrained_model \
    --policy.input_features='{"observation.images.workspace":{"type":"VISUAL","shape":[3,480,640]},"observation.images.wrist":{"type":"VISUAL","shape":[3,480,640]},"observation.state":{"type":"STATE","shape":[6]}}' \
    --policy.output_features='{"action":{"type":"ACTION","shape":[6]}}'
```

## Known Issues & Fixes
1. Servo bus collision → replaced sync_read with individual reads
2. torchvision VideoReader missing → patched to use av directly
3. HuggingFace hub check → patched to use local files
4. Camera paths change on reboot → use /dev/v4l/by-id/ persistent paths

## Dataset
- 1 camera dataset: 32 episodes, 14K frames
- 2 camera dataset: 110 episodes, 44K frames

## Results
- Robot successfully learns pick and place task
- Tested with variable object and tray positions (9x9 zone grid)
- Workspace: 50cm wide x 21cm deep

## Dataset Download

### 1-Camera Dataset (32 episodes, 14K frames, 96MB)
- Camera: Arducam IMX477 (workspace/top view only)
- FPS: 15
- Resolution: 640x480
- Task: Pick and place object

**Download:** https://drive.google.com/file/d/1Fcs4L1rHC1loITgYCjOsfwKJwtMAe-ad/view?usp=sharing

### How to use:
```bash
# Download and extract
gdown "https://drive.google.com/uc?id=1Fcs4L1rHC1loITgYCjOsfwKJwtMAe-ad"
mkdir -p ~/.cache/huggingface/lerobot/
tar -xzf so100_pick_place_1cam.tar.gz -C ~/.cache/huggingface/lerobot/
```

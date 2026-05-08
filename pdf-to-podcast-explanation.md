# PDF-to-Podcast: Giải thích source code

## 1) Bóc tách và tùy biến source code

### Cấu trúc tổng quan
- `services/APIService/`: API gateway, nhận file PDF, điều phối pipeline, trả status/output cho client.
- `services/PDFService/`: chuyển PDF -> markdown để đưa vào Agent (đang dùng xử lý local trong service).
- `services/AgentService/`: xử lý LLM để sinh transcript (monologue hoặc dialogue).
- `services/TTSService/`: chuyển transcript thành audio MP3 (ElevenLabs).
- `shared/shared/`: thành phần dùng chung (job status Redis, storage MinIO, type models, telemetry).
- `frontend/`: Gradio UI để upload PDF, cấu hình model, tải transcript/history.

### Các điểm tùy biến quan trọng
- Tùy biến model LLM:
  - Sửa `models.json` để đổi model và endpoint (`reasoning`, `json`, `iteration`).
  - Agent service đọc config qua env `MODEL_CONFIG_PATH` (xem `services/AgentService/main.py`).
  - Hiện tại biến này được set trực tiếp trong `docker-compose.yaml` (`MODEL_CONFIG_PATH=/app/config/models.json`) và map volume từ `./models.json`.
  - Nghĩa là mặc định **không lấy từ `.env`** và cũng **không lấy từ `variables.env`**.
  - `variables.env` chủ yếu dùng cho AI Workbench/container shell; luồng chạy bằng `setup.sh` + `docker compose --env-file .env` sử dụng `.env` cho các biến kiểu API key.
- Tùy biến prompt và phong cách nội dung:
  - Podcast 2 người: `services/AgentService/podcast_flow.py` + `services/AgentService/podcast_prompts.py`.
  - Monologue 1 người: `services/AgentService/monologue_flow.py` + `services/AgentService/monologue_prompts.py`.
- Tùy biến voice TTS:
  - `services/TTSService/main.py`: `DEFAULT_VOICE_1`, `DEFAULT_VOICE_2`, `MAX_CONCURRENT_REQUESTS`.
  - Có thể truyền `voice_mapping` theo request để map theo từng speaker.
- Tùy biến UI:
  - `frontend/__main__.py`: tabs, upload flow, editor cho `models.json`, xuất transcript/history.

## 2) Khởi động hệ thống

### Điều kiện cần
- Docker Desktop + Docker Compose.
- Bash shell:
  - Windows: Git Bash (hoặc WSL).
  - Linux: bash mặc định của hệ thống.
- API keys trong `.env`:
  - `NVIDIA_API_KEY=...`
  - `ELEVENLABS_API_KEY=...`
  - `MAX_CONCURRENT_REQUESTS=1`

### Cách chạy chuẩn bằng script (khuyến nghị)
Script `setup.sh` đã hỗ trợ full lifecycle:
- `--up`: khởi động toàn bộ từ đầu hoặc cho những lần chạy lại.
- `--down`: dừng toàn bộ hệ thống.
- `--clean`: reset sạch tuyệt đối (stop + remove volumes + xóa artifacts local).

### Lệnh chạy trên Windows (PowerShell)
```powershell
# Khởi động toàn bộ
& "C:\Program Files\Git\bin\bash.exe" .\setup.sh --up

# Dừng toàn bộ
& "C:\Program Files\Git\bin\bash.exe" .\setup.sh --down

# Reset sạch tuyệt đối
& "C:\Program Files\Git\bin\bash.exe" .\setup.sh --clean
```

### Lệnh chạy trên Linux
```bash
# Tại thư mục project
cd /path/to/pdf-to-podcast

# Cấp quyền chạy script (lần đầu)
chmod +x setup.sh

# Khởi động toàn bộ
./setup.sh --up

# Dừng toàn bộ
./setup.sh --down

# Reset sạch tuyệt đối
./setup.sh --clean
```

### Script `--up` sẽ làm gì?
1. Kiểm tra công cụ bắt buộc.
2. Cài `uv` nếu chưa có.
3. Tạo `.venv`, tự kích hoạt, cài `requirements.txt` và `shared/`.
4. Tự kiểm tra xung đột port và chọn port trống.
5. Sinh file `.auto-ports.compose.yaml` để override port Docker.
6. Chạy toàn bộ services bằng Docker Compose.
7. Chạy frontend local ở background và in đầy đủ URL truy cập.

### Các file tự sinh sau khi chạy `--up`
- `.auto-ports.env`: map tất cả port đã chọn.
- `.auto-ports.compose.yaml`: file override port cho Docker.
- `frontend/output.log`: log frontend.
- `frontend/.frontend.pid`: PID frontend local.

## 3) Hướng dẫn sử dụng UI

### Mở giao diện
1. Chạy `setup.sh --up`.
2. Lấy URL frontend từ output script (mặc định thường là `http://localhost:7860`, nhưng có thể tự đổi nếu trùng port).
3. Mở URL đó trên trình duyệt.

### Chạy một lần tạo podcast
1. Vào tab **Full End to End Flow**.
2. Upload **target PDF** (bắt buộc).
3. Upload **context PDF** (tùy chọn, có thể để trống).
4. Chọn **Monologue Only** nếu muốn 1 người nói.
5. (Tùy chọn) nhập email nhận file.
6. Bấm **Generate Podcast**.
7. Theo dõi log ở khung **Outputs**.
8. Khi hoàn tất, tải:
   - File MP3
   - Transcript JSON
   - Generation history JSON

### Ý nghĩa từng lựa chọn trong UI
- Target PDF: tài liệu chính để tạo nội dung podcast.
- Context PDF: tài liệu bổ sung để tăng chất lượng giải thích/ngữ cảnh.
- Monologue Only:
  - Bật: 1 người nói.
  - Tắt: 2 người đối thoại.

## 4) Hướng dẫn xem logs

### Windows (PowerShell)

#### Xem logs toàn bộ Docker services
```powershell
docker compose -f docker-compose.yaml -f .auto-ports.compose.yaml --env-file .env logs -f
```

#### Xem logs từng service
```powershell
docker compose -f docker-compose.yaml -f .auto-ports.compose.yaml --env-file .env logs -f api-service
docker compose -f docker-compose.yaml -f .auto-ports.compose.yaml --env-file .env logs -f pdf-service
docker compose -f docker-compose.yaml -f .auto-ports.compose.yaml --env-file .env logs -f agent-service
docker compose -f docker-compose.yaml -f .auto-ports.compose.yaml --env-file .env logs -f tts-service
```

#### Xem log frontend local
```powershell
Get-Content .\frontend\output.log -Wait
```

#### Xem nhanh 100 dòng gần nhất
```powershell
docker compose -f docker-compose.yaml -f .auto-ports.compose.yaml --env-file .env logs --tail 100
```

### Linux (bash)

#### Xem logs toàn bộ Docker services
```bash
docker compose -f docker-compose.yaml -f .auto-ports.compose.yaml --env-file .env logs -f
```

#### Xem logs từng service
```bash
docker compose -f docker-compose.yaml -f .auto-ports.compose.yaml --env-file .env logs -f api-service
docker compose -f docker-compose.yaml -f .auto-ports.compose.yaml --env-file .env logs -f pdf-service
docker compose -f docker-compose.yaml -f .auto-ports.compose.yaml --env-file .env logs -f agent-service
docker compose -f docker-compose.yaml -f .auto-ports.compose.yaml --env-file .env logs -f tts-service
```

#### Xem log frontend local
```bash
tail -f frontend/output.log
```

#### Xem nhanh 100 dòng gần nhất
```bash
docker compose -f docker-compose.yaml -f .auto-ports.compose.yaml --env-file .env logs --tail 100
```

### Dừng theo dõi log realtime
- Nhấn `Ctrl + C` trong terminal đang tail log.

## 5) Phân tích ngắn gọn cách lõi hoạt động

### Luồng xử lý chính
1. Client gọi `POST /process_pdf` vào API service (`services/APIService/main.py`).
2. API tạo `job_id`, lưu PDF gốc vào MinIO, rồi gửi sang PDF service (`/convert`).
3. PDF service chuyển PDF -> markdown (đang xử lý local trong service), lưu kết quả vào Redis (`result:<job_id>:pdf`) và cập nhật status.
4. API lắng nghe status qua Redis pub/sub (`status_updates:all`). Khi PDF xong, API gọi Agent service (`/transcribe`).
5. Agent service sinh transcript:
   - Tóm tắt từng PDF.
   - Tạo outline.
   - Sinh đoạn hội thoại/monologue.
   - Hợp nhất thành `Conversation` JSON.
6. API lấy transcript từ Agent, lưu JSON vào MinIO, rồi gọi TTS service (`/generate_tts`).
7. TTS service sinh MP3 theo từng segment, cập nhật status, lưu audio vào Redis result.
8. API lấy MP3, lưu bản final vào MinIO, trả output qua `GET /output/{job_id}`.

### Thành phần lõi và vai trò
- Redis:
  - Lưu `status:*` và `result:*` tạm thời cho từng service.
  - Pub/sub để stream status realtime cho WebSocket (`/ws/status/{job_id}`).
- MinIO:
  - Lưu dữ liệu bền vững: PDF gốc, transcript JSON, prompt tracker history, MP3.
- `.env`:
  - Chứa biến môi trường phục vụ chạy local qua Docker Compose (NVIDIA/ElevenLabs API key, v.v.).
- `variables.env`:
  - File cấu hình theo ngữ cảnh AI Workbench; không phải nguồn config chính cho flow `setup.sh --up` hiện tại.
- JobStatusManager (`shared/shared/job.py`):
  - Đồng bộ trạng thái `pending -> processing -> completed/failed` cho từng service.
- ConnectionManager (`shared/shared/connection.py`):
  - Cầu nối Redis pub/sub -> WebSocket để frontend theo dõi progress theo `job_id`.

### Đầu vào / đầu ra
- Đầu vào: 1+ target PDF, 0+ context PDF, tham số hướng dẫn (guide, duration, speaker, voice mapping...).
- Đầu ra chính:
  - MP3 podcast.
  - Transcript JSON (`..._agent_result.json`).
  - Prompt history (`..._prompt_tracker.json`) để audit quy trình sinh nội dung.

## 6) Checklist tùy biến nhanh theo use case (tùy chọn)
- Đổi model và endpoint LLM trong `models.json`.
- Chỉnh prompt trong `podcast_prompts.py` / `monologue_prompts.py`.
- Chỉnh voice defaults và mapping trong TTS service.
- Chỉnh `docker-compose.yaml` khi muốn đổi wiring nội bộ (bao gồm `MODEL_CONFIG_PATH`).
- Chỉnh `.env` khi muốn đổi biến runtime bên ngoài service (API keys, giới hạn request...).
- Bật tracing Jaeger (URL theo port script in ra) để theo dõi latency từng bước.

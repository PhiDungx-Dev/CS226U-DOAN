#!/bin/bash

LOG_FILE="./autofilemanager.log"
TRASH_DIR="$HOME/.local/share/Trash"
TEMP_DIR="/tmp"
BACKUP_DIR="$HOME/backup"  # Thư mục sao lưu mặc định

# =========================
# Nhập đường dẫn thư mục nguồn
# =========================
function get_source_dir() {
    while true; do
        echo "Vui lòng nhập đường dẫn thư mục nguồn (SOURCE_DIR)."
        echo " Ví dụ: /home/tennguoidung/Downloads"
        read -p "Nhập đường dẫn thư mục nguồn: " SOURCE_DIR
        if [[ -d "$SOURCE_DIR" ]]; then
            echo "Đường dẫn thư mục nguồn: $SOURCE_DIR"
            break
        else
            echo "Thư mục không tồn tại. Vui lòng nhập lại."
        fi
    done
}

# =========================
# 1. Phân loại tập tin
# =========================
function classify_files() {
    echo "=== Phân loại tập tin ===" | tee -a "$LOG_FILE"

    mkdir -p "$HOME/Images" "$HOME/Videos" "$HOME/Documents" "$HOME/Music" "$HOME/Archives" "$HOME/Others"

    # Di chuyển các tập tin vào các thư mục phân loại
    for file in "$SOURCE_DIR"/*; do
        if [[ -f "$file" ]]; then
            case "${file##*.}" in
                # Định dạng hình ảnh
                jpg|png|jpeg|gif|bmp|tiff|svg) 
                    mv "$file" "$HOME/Images/"
                    echo "Đã chuyển ảnh: $file vào thư mục: $HOME/Images" | tee -a "$LOG_FILE" ;;
                # Định dạng video
                mp4|mkv|avi|mov|wmv|flv|webm)
                    mv "$file" "$HOME/Videos/"
                    echo "Đã chuyển video: $file vào thư mục: $HOME/Videos" | tee -a "$LOG_FILE" ;;
                # Định dạng tài liệu
                pdf|doc|docx|ppt|pptx|xls|xlsx|txt|odt)
                    mv "$file" "$HOME/Documents/"
                    echo "Đã chuyển tài liệu: $file vào thư mục: $HOME/Documents" | tee -a "$LOG_FILE" ;;
                # Định dạng âm nhạc
                mp3|wav|flac|aac|ogg|m4a|wma)
                    mv "$file" "$HOME/Music/"
                    echo "Đã chuyển âm nhạc: $file vào thư mục: $HOME/Music" | tee -a "$LOG_FILE" ;;
                # Định dạng nén
                zip|rar|7z|tar|gz|bz2|xz)
                    mv "$file" "$HOME/Archives/"
                    echo "Đã chuyển archive: $file vào thư mục: $HOME/Archives" | tee -a "$LOG_FILE" ;;
                # Các loại khác
                *) 
                    mv "$file" "$HOME/Others/"
                    echo "Đã chuyển tệp khác: $file vào thư mục: $HOME/Others" | tee -a "$LOG_FILE" ;;
            esac
        fi
    done
    echo "Phân loại hoàn tất! Các tập tin đã được chuyển vào thư mục tương ứng." | tee -a "$LOG_FILE"
}

# =========================
# 2. Sao lưu tập tin (sử dụng rsync)
# =========================
function backup_files() {
    echo "=== Sao lưu tập tin ===" | tee -a "$LOG_FILE"

    TIMESTAMP=$(date +"%Y%m%d_%H%M")
    BACKUP_SUBDIR="$BACKUP_DIR/backup_$TIMESTAMP"

    mkdir -p "$BACKUP_SUBDIR"

    # Sử dụng rsync để sao lưu
    rsync -av --progress "$SOURCE_DIR/" "$BACKUP_SUBDIR/" | tee -a "$LOG_FILE"

    if [[ $? -eq 0 ]]; then
        echo "Sao lưu thành công vào thư mục: $BACKUP_SUBDIR" | tee -a "$LOG_FILE"
    else
        echo "Sao lưu thất bại!" | tee -a "$LOG_FILE"
    fi
}

# =========================
# 3. Khôi phục tập tin (sử dụng rsync)
# =========================
function restore_files() {
    echo "=== Khôi phục tập tin ===" | tee -a "$LOG_FILE"

    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "Thư mục sao lưu không tồn tại. Không thể khôi phục!" | tee -a "$LOG_FILE"
        return
    fi

    # Kiểm tra nếu không có bản sao lưu nào trong thư mục backup
    BACKUPS=$(ls -d "$BACKUP_DIR"/* 2>/dev/null)
    if [[ -z "$BACKUPS" ]]; then
        echo "Không có bản sao lưu nào trong thư mục $BACKUP_DIR để khôi phục!" | tee -a "$LOG_FILE"
        return
    fi

    echo "Danh sách các bản sao lưu:"
    select backup in "$BACKUP_DIR"/*; do
        if [[ -n "$backup" && -d "$backup" ]]; then
            echo "Bạn đã chọn bản sao lưu: $backup"
            read -p "Bạn có muốn ghi đè tệp hiện tại không? (y/n): " overwrite
            case $overwrite in
                y|Y)
                    rsync -av --progress "$backup/" "$SOURCE_DIR/" | tee -a "$LOG_FILE"
                    echo "Khôi phục với ghi đè hoàn tất!" | tee -a "$LOG_FILE"
                    ;;
                n|N)
                    rsync -av --progress --ignore-existing "$backup/" "$SOURCE_DIR/" | tee -a "$LOG_FILE"
                    echo "Khôi phục không ghi đè hoàn tất!" | tee -a "$LOG_FILE"
                    ;;
                *)
                    echo "Lựa chọn không hợp lệ. Hủy khôi phục." | tee -a "$LOG_FILE"
                    ;;
            esac
            break
        else
            echo "Lựa chọn không hợp lệ. Vui lòng thử lại."
        fi
    done
}

# =========================
# 4. Dọn dẹp tập tin tạm
# =========================
function cleanup_temp_files() {
    echo "=== Dọn dẹp thư mục tạm thời ===" | tee -a "$LOG_FILE"

    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR/"*
        echo "Đã dọn dẹp thư mục tạm thời tại: $TEMP_DIR" | tee -a "$LOG_FILE"
    else
        echo "Không tìm thấy thư mục tạm thời tại: $TEMP_DIR" | tee -a "$LOG_FILE"
    fi
}

# =========================
# 5. Xóa thùng rác
# =========================
function empty_trash() {
    echo "=== Xóa thùng rác ===" | tee -a "$LOG_FILE"

    if [[ -d "$TRASH_DIR" ]]; then
        rm -rf "$TRASH_DIR/files/"* "$TRASH_DIR/info/"*
        echo "Thùng rác đã được làm trống!" | tee -a "$LOG_FILE"
    else
        echo "Không tìm thấy thư mục thùng rác tại: $TRASH_DIR" | tee -a "$LOG_FILE"
    fi
}

# =========================
# Menu điều khiển
# =========================
function main_menu() {
    echo "=========================="
    echo "Quản lý tập tin tự động"
    echo "=========================="
    echo "1. Phân loại tập tin"
    echo "2. Sao lưu tập tin"
    echo "3. Khôi phục tập tin"
    echo "4. Dọn dẹp thư mục tạm thời"
    echo "5. Xóa thùng rác"
    echo "6. Thoát"
    echo "=========================="
    read -p "Chọn tác vụ (1-6): " choice

    case $choice in
        1) classify_files ;;
        2) backup_files ;;
        3) restore_files ;;
        4) cleanup_temp_files ;;
        5) empty_trash ;;
        6) echo "Thoát chương trình."; exit 0 ;;
        *) echo "Lựa chọn không hợp lệ!"; main_menu ;;
    esac
}

# =========================
# Khởi động chương trình
# =========================
echo "=== Chương trình bắt đầu ==="

# Nhập thư mục nguồn
get_source_dir

# Kiểm tra thư mục sao lưu và tạo nếu không tồn tại
if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "Thư mục sao lưu không tồn tại. Đang tạo: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
fi

# Chạy menu
while true; do
    main_menu
done

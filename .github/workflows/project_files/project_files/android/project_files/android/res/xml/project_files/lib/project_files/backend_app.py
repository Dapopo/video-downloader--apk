from flask import Flask, request, send_file, jsonify
import yt_dlp
import os
import tempfile

app = Flask(__name__)

@app.route('/info')
def info():
    url = request.args.get('url')
    ydl_opts = {
        'quiet': True,
        'skip_download': True
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info_dict = ydl.extract_info(url, download=False)
        return jsonify({
            'title': info_dict.get('title'),
            'thumbnail': info_dict.get('thumbnail')
        })

@app.route('/download', methods=['POST'])
def download():
    url = request.form.get('url')
    tmp_file = tempfile.NamedTemporaryFile(delete=False, suffix=".mp4")
    tmp_path = tmp_file.name
    tmp_file.close()

    ydl_opts = {
        'outtmpl': tmp_path,
        'format': 'bestvideo+bestaudio/best',
        'merge_output_format': 'mp4'
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        ydl.download([url])

    return send_file(tmp_path, as_attachment=True, download_name="video.mp4")

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

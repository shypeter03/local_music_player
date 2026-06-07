const AUDIO_EXTENSIONS = new Set(["mp3", "m4a", "aac", "wav", "flac", "ogg"]);
const IMAGE_EXTENSIONS = new Set(["jpg", "jpeg", "png", "webp"]);
const DB_NAME = "local-music-player";
const DB_VERSION = 1;
const STORE_NAME = "folders";

const state = {
  folders: [],
  tracks: [],
  filteredTracks: [],
  recentIds: JSON.parse(localStorage.getItem("recentTracks") || "[]"),
  currentTrack: null,
  currentIndex: -1,
  lyrics: [],
  isSeeking: false,
  artworkUrl: "",
};

const els = {
  audio: document.querySelector("#audio"),
  pages: document.querySelectorAll(".page"),
  tabs: document.querySelectorAll(".nav-tab"),
  trackList: document.querySelector("#trackList"),
  recentList: document.querySelector("#recentList"),
  folderList: document.querySelector("#folderList"),
  folderInput: document.querySelector("#folderInput"),
  miniPlayer: document.querySelector("#miniPlayer"),
  nowCard: document.querySelector("#nowCard"),
  searchInput: document.querySelector("#searchInput"),
  libraryCount: document.querySelector("#libraryCount"),
  folderCount: document.querySelector("#folderCount"),
  addFolderBtn: document.querySelector("#addFolderBtn"),
  scanFoldersBtn: document.querySelector("#scanFoldersBtn"),
  rescanBtn: document.querySelector("#rescanBtn"),
  clearRecentBtn: document.querySelector("#clearRecentBtn"),
  playPauseBtn: document.querySelector("#playPauseBtn"),
  detailPlayBtn: document.querySelector("#detailPlayBtn"),
  prevBtn: document.querySelector("#prevBtn"),
  nextBtn: document.querySelector("#nextBtn"),
  detailPrevBtn: document.querySelector("#detailPrevBtn"),
  detailNextBtn: document.querySelector("#detailNextBtn"),
  seekBar: document.querySelector("#seekBar"),
  miniSeek: document.querySelector("#miniSeek"),
  sideSeek: document.querySelector("#sideSeek"),
  currentTime: document.querySelector("#currentTime"),
  durationTime: document.querySelector("#durationTime"),
  miniCurrentTime: document.querySelector("#miniCurrentTime"),
  miniDuration: document.querySelector("#miniDuration"),
  sideCurrentTime: document.querySelector("#sideCurrentTime"),
  sideDuration: document.querySelector("#sideDuration"),
  lyricsList: document.querySelector("#lyricsList"),
  lyricsStatus: document.querySelector("#lyricsStatus"),
  nowStatus: document.querySelector("#nowStatus"),
  backToLibraryBtn: document.querySelector("#backToLibraryBtn"),
};

const textTargets = {
  miniTitle: document.querySelector("#miniTitle"),
  miniArtist: document.querySelector("#miniArtist"),
  nowTitle: document.querySelector("#nowTitle"),
  nowArtist: document.querySelector("#nowArtist"),
  playerTitle: document.querySelector("#playerTitle"),
  detailArtist: document.querySelector("#detailArtist"),
  detailFolder: document.querySelector("#detailFolder"),
};

function openDatabase() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = () => {
      request.result.createObjectStore(STORE_NAME, { keyPath: "id" });
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function dbAction(mode, action) {
  const db = await openDatabase();
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(STORE_NAME, mode);
    const store = transaction.objectStore(STORE_NAME);
    const result = action(store);
    transaction.oncomplete = () => resolve(result);
    transaction.onerror = () => reject(transaction.error);
  }).finally(() => db.close());
}

async function loadFolders() {
  const db = await openDatabase();
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(STORE_NAME, "readonly");
    const request = transaction.objectStore(STORE_NAME).getAll();
    request.onsuccess = () => resolve(request.result || []);
    request.onerror = () => reject(request.error);
    transaction.oncomplete = () => db.close();
  });
}

function saveFolder(folder) {
  return dbAction("readwrite", (store) => store.put(folder));
}

function deleteFolder(id) {
  return dbAction("readwrite", (store) => store.delete(id));
}

function makeId() {
  return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function formatTime(seconds) {
  if (!Number.isFinite(seconds)) return "0:00";
  const whole = Math.max(0, Math.floor(seconds));
  const minutes = Math.floor(whole / 60);
  const rest = String(whole % 60).padStart(2, "0");
  return `${minutes}:${rest}`;
}

function formatFileSize(bytes) {
  if (!bytes) return "";
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function splitTrackName(fileName) {
  const base = fileName.replace(/\.[^.]+$/, "");
  const parts = base.split(/\s+-\s+/);
  if (parts.length >= 2) {
    return {
      artist: parts[0].trim(),
      title: parts.slice(1).join(" - ").trim(),
    };
  }
  return { artist: "未知艺术家", title: base };
}

function isAudioFile(name) {
  const ext = name.split(".").pop().toLowerCase();
  return AUDIO_EXTENSIONS.has(ext);
}

function isLyricFile(name) {
  return name.toLowerCase().endsWith(".lrc");
}

function isImageFile(name) {
  const ext = name.split(".").pop().toLowerCase();
  return IMAGE_EXTENSIONS.has(ext);
}

async function verifyPermission(handle, writable = false) {
  const options = writable ? { mode: "readwrite" } : {};
  if ((await handle.queryPermission(options)) === "granted") return true;
  return (await handle.requestPermission(options)) === "granted";
}

async function scanDirectory(folder, directoryHandle, basePath = "") {
  const tracks = [];
  const lyricFiles = new Map();
  const imageFiles = new Map();

  for await (const entry of directoryHandle.values()) {
    const path = basePath ? `${basePath}/${entry.name}` : entry.name;
    if (entry.kind === "directory") {
      const nested = await scanDirectory(folder, entry, path);
      tracks.push(...nested.tracks);
      nested.lyricFiles.forEach((value, key) => lyricFiles.set(key, value));
      nested.imageFiles.forEach((value, key) => imageFiles.set(key, value));
      continue;
    }

    if (entry.kind !== "file") continue;
    if (isLyricFile(entry.name)) {
      lyricFiles.set(path.replace(/\.lrc$/i, "").toLowerCase(), entry);
      continue;
    }
    if (isImageFile(entry.name)) {
      registerArtwork(imageFiles, path, entry);
      continue;
    }

    if (!isAudioFile(entry.name)) continue;
    const file = await entry.getFile();
    const parsed = splitTrackName(entry.name);
    tracks.push({
      id: `${folder.id}:${path}`,
      folderId: folder.id,
      folderName: folder.name,
      path,
      fileName: entry.name,
      title: parsed.title,
      artist: parsed.artist,
      extension: entry.name.split(".").pop().toUpperCase(),
      size: file.size,
      modified: file.lastModified,
      handle: entry,
      lyricHandle: null,
    });
  }

  tracks.forEach((track) => {
    const lyricKey = track.path.replace(/\.[^.]+$/, "").toLowerCase();
    const artworkKey = getArtworkKey(track.path);
    track.lyricHandle = lyricFiles.get(lyricKey) || null;
    track.artworkHandle = imageFiles.get(lyricKey) || imageFiles.get(artworkKey) || null;
  });

  return { tracks, lyricFiles, imageFiles };
}

function scanSelectedFiles(folder, files) {
  const lyricFiles = new Map();
  const imageFiles = new Map();
  const audioFiles = [];

  files.forEach((file) => {
    const path = file.webkitRelativePath || file.name;
    if (isLyricFile(file.name)) {
      lyricFiles.set(path.replace(/\.lrc$/i, "").toLowerCase(), file);
    } else if (isImageFile(file.name)) {
      registerArtwork(imageFiles, path, file);
    } else if (isAudioFile(file.name)) {
      audioFiles.push({ file, path });
    }
  });

  return audioFiles.map(({ file, path }) => {
    const parsed = splitTrackName(file.name);
    const lyricKey = path.replace(/\.[^.]+$/, "").toLowerCase();
    const artworkKey = getArtworkKey(path);
    return {
      id: `${folder.id}:${path}`,
      folderId: folder.id,
      folderName: folder.name,
      path,
      fileName: file.name,
      title: parsed.title,
      artist: parsed.artist,
      extension: file.name.split(".").pop().toUpperCase(),
      size: file.size,
      modified: file.lastModified,
      handle: null,
      file,
      lyricHandle: null,
      lyricFile: lyricFiles.get(lyricKey) || null,
      artworkHandle: null,
      artworkFile: imageFiles.get(lyricKey) || imageFiles.get(artworkKey) || null,
    };
  });
}

function registerArtwork(imageFiles, path, fileOrHandle) {
  const normalized = path.toLowerCase();
  const baseKey = normalized.replace(/\.[^.]+$/, "");
  const fileName = normalized.split("/").pop().replace(/\.[^.]+$/, "");
  const folder = normalized.includes("/") ? normalized.split("/").slice(0, -1).join("/") : "";
  imageFiles.set(baseKey, fileOrHandle);
  if (["cover", "folder", "album"].includes(fileName)) {
    imageFiles.set(folder ? `${folder}/__cover` : "__cover", fileOrHandle);
  }
}

function getArtworkKey(path) {
  const folder = path.toLowerCase().includes("/") ? path.toLowerCase().split("/").slice(0, -1).join("/") : "";
  return folder ? `${folder}/__cover` : "__cover";
}

async function scanFolders() {
  setStatus("正在扫描文件夹…");
  const allTracks = [];

  for (const folder of state.folders) {
    try {
      if (folder.files) {
        const fileTracks = scanSelectedFiles(folder, folder.files);
        allTracks.push(...fileTracks);
        folder.permission = "本次会话已选择";
        folder.trackCount = fileTracks.length;
        continue;
      }

      const hasPermission = await verifyPermission(folder.handle);
      folder.permission = hasPermission ? "已授权" : "需要授权";
      if (!hasPermission) continue;
      const result = await scanDirectory(folder, folder.handle);
      allTracks.push(...result.tracks);
      folder.trackCount = result.tracks.length;
      await saveFolder(folder);
    } catch (error) {
      folder.permission = "读取失败";
      folder.error = error.message;
    }
  }

  state.tracks = allTracks.sort((a, b) => a.title.localeCompare(b.title, "zh-Hans-CN"));
  applySearch();
  renderFolders();
  setStatus(state.tracks.length ? `已载入 ${state.tracks.length} 首` : "没有扫描到音乐");
}

function setStatus(message) {
  els.nowStatus.textContent = message;
}

function showPage(page) {
  els.pages.forEach((item) => item.classList.toggle("is-active", item.id === `${page}Page`));
  els.tabs.forEach((item) => item.classList.toggle("is-active", item.dataset.page === page));
}

function openPlayerDetail() {
  if (!state.currentTrack && state.tracks[0]) {
    playTrack(state.tracks[0].id);
  }
  showPage("player");
}

function isPlayerControl(target) {
  return Boolean(target.closest("button, input, label, a"));
}

function applySearch() {
  const query = els.searchInput.value.trim().toLowerCase();
  state.filteredTracks = query
    ? state.tracks.filter((track) =>
        [track.title, track.artist, track.folderName, track.fileName, track.path]
          .join(" ")
          .toLowerCase()
          .includes(query),
      )
    : [...state.tracks];
  renderTracks();
  renderRecent();
}

function renderTracks() {
  els.libraryCount.textContent = `${state.filteredTracks.length} 首`;
  if (!state.filteredTracks.length) {
    els.trackList.innerHTML = `<div class="empty">还没有音乐。前往“文件夹”页面选择本地或 iCloud 文件夹。</div>`;
    return;
  }

  els.trackList.innerHTML = state.filteredTracks
    .map((track, index) => {
      const active = state.currentTrack?.id === track.id ? " is-active" : "";
      return `
        <button class="track-row${active}" data-track-id="${track.id}" type="button">
          <span class="track-index">${index + 1}</span>
          <span class="track-main">
            <strong class="track-title">${escapeHtml(track.title)}</strong>
            <span class="track-subtitle">${escapeHtml(track.artist)} · ${escapeHtml(track.folderName)}</span>
          </span>
          <span class="track-meta">
            <span class="pill">${track.extension}</span>
            ${formatFileSize(track.size)}
          </span>
        </button>
      `;
    })
    .join("");
}

function renderRecent() {
  const recentTracks = state.recentIds
    .map((id) => state.tracks.find((track) => track.id === id))
    .filter(Boolean)
    .slice(0, 8);

  if (!recentTracks.length) {
    els.recentList.innerHTML = `<div class="empty">播放后会出现在这里</div>`;
    return;
  }

  els.recentList.innerHTML = recentTracks
    .map(
      (track) => `
        <button class="recent-row" data-track-id="${track.id}" type="button">
          <span class="recent-main">
            <strong class="recent-title">${escapeHtml(track.title)}</strong>
            <span class="recent-subtitle">${escapeHtml(track.artist)} · ${escapeHtml(track.folderName)}</span>
          </span>
          <span class="pill">${track.extension}</span>
        </button>
      `,
    )
    .join("");
}

function renderFolders() {
  els.folderCount.textContent = `${state.folders.length} 个`;
  if (!state.folders.length) {
    els.folderList.innerHTML = `<div class="empty">尚未添加文件夹，可多次选择本地和 iCloud 文件夹。</div>`;
    return;
  }

  els.folderList.innerHTML = state.folders
    .map(
      (folder) => `
        <div class="folder-row">
          <span class="folder-main">
            <strong>${escapeHtml(folder.name)}</strong>
            <span class="folder-path">${escapeHtml(folder.permission || "待授权")} · ${folder.trackCount || 0} 首</span>
          </span>
          <button class="text-button danger" data-folder-remove="${folder.id}" type="button">移除</button>
        </div>
      `,
    )
    .join("");
}

function renderCurrentTrack() {
  const track = state.currentTrack;
  const title = track?.title || "还没有播放歌曲";
  const artist = track?.artist || "从文件夹导入音乐开始";
  const folder = track ? `${track.folderName} / ${track.path}` : "未选择来源";

  textTargets.miniTitle.textContent = title;
  textTargets.nowTitle.textContent = track ? title : "请选择一首歌";
  textTargets.playerTitle.textContent = title;
  textTargets.miniArtist.textContent = artist;
  textTargets.nowArtist.textContent = track ? `${artist} · ${track.extension}` : "支持 mp3、m4a、aac、wav、flac、ogg";
  textTargets.detailArtist.textContent = artist;
  textTargets.detailFolder.textContent = folder;
  updateArtwork(track);

  document.querySelectorAll(".track-row").forEach((row) => {
    row.classList.toggle("is-active", row.dataset.trackId === track?.id);
  });

  renderRecent();
}

async function updateArtwork(track) {
  if (state.artworkUrl) {
    URL.revokeObjectURL(state.artworkUrl);
    state.artworkUrl = "";
  }

  const artwork = track?.artworkFile || (track?.artworkHandle ? await track.artworkHandle.getFile() : null);
  const coverElements = document.querySelectorAll(".cover, .album-art");
  if (!artwork) {
    coverElements.forEach((cover) => {
      cover.classList.remove("has-art");
      cover.style.backgroundImage = "";
      cover.textContent = "♪";
    });
    return;
  }

  state.artworkUrl = URL.createObjectURL(artwork);
  coverElements.forEach((cover) => {
    cover.classList.add("has-art");
    cover.style.backgroundImage = `url("${state.artworkUrl}")`;
    cover.textContent = "";
  });
}

async function playTrack(trackId) {
  const track = state.tracks.find((item) => item.id === trackId);
  if (!track) return;

  const file = track.file || (await track.handle.getFile());
  if (els.audio.src) URL.revokeObjectURL(els.audio.src);
  els.audio.src = URL.createObjectURL(file);
  state.currentTrack = track;
  state.currentIndex = state.tracks.findIndex((item) => item.id === track.id);
  addRecent(track.id);
  await loadLyrics(track);
  renderCurrentTrack();
  await els.audio.play();
}

function addRecent(trackId) {
  state.recentIds = [trackId, ...state.recentIds.filter((id) => id !== trackId)].slice(0, 20);
  localStorage.setItem("recentTracks", JSON.stringify(state.recentIds));
}

async function loadLyrics(track) {
  state.lyrics = [];
  if (!track.lyricHandle && !track.lyricFile) {
    els.lyricsStatus.textContent = "未找到同名 .lrc";
    renderLyrics();
    return;
  }

  try {
    const file = track.lyricFile || (await track.lyricHandle.getFile());
    const text = await file.text();
    state.lyrics = parseLrc(text);
    els.lyricsStatus.textContent = state.lyrics.length ? `${state.lyrics.length} 行歌词` : "歌词文件为空";
  } catch (error) {
    els.lyricsStatus.textContent = "歌词读取失败";
  }
  renderLyrics();
}

function parseLrc(text) {
  return text
    .split(/\r?\n/)
    .flatMap((line) => {
      const matches = [...line.matchAll(/\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]/g)];
      const content = line.replace(/\[[^\]]+\]/g, "").trim();
      if (!matches.length || !content) return [];
      return matches.map((match) => ({
        time: Number(match[1]) * 60 + Number(match[2]) + Number(`0.${match[3] || 0}`),
        text: content,
      }));
    })
    .sort((a, b) => a.time - b.time);
}

function renderLyrics() {
  if (!state.lyrics.length) {
    els.lyricsList.innerHTML = `<div class="empty">将同名 .lrc 文件放在歌曲旁边即可显示歌词。</div>`;
    return;
  }

  els.lyricsList.innerHTML = state.lyrics
    .map((line, index) => `<div class="lyric-line" data-lyric-index="${index}">${escapeHtml(line.text)}</div>`)
    .join("");
  highlightLyric();
}

function highlightLyric() {
  if (!state.lyrics.length) return;
  const current = els.audio.currentTime;
  let activeIndex = state.lyrics.findIndex((line, index) => {
    const next = state.lyrics[index + 1];
    return current >= line.time && (!next || current < next.time);
  });
  if (activeIndex < 0) activeIndex = 0;

  document.querySelectorAll(".lyric-line").forEach((line) => {
    const active = Number(line.dataset.lyricIndex) === activeIndex;
    line.classList.toggle("is-current", active);
    if (active) line.scrollIntoView({ block: "center", behavior: "smooth" });
  });
}

function updateProgress() {
  const current = els.audio.currentTime;
  const duration = els.audio.duration;
  const percent = Number.isFinite(duration) && duration > 0 ? (current / duration) * 100 : 0;

  if (!state.isSeeking) {
    els.seekBar.value = percent;
    els.miniSeek.value = percent;
    els.sideSeek.value = percent;
  }

  els.currentTime.textContent = formatTime(current);
  els.miniCurrentTime.textContent = formatTime(current);
  els.sideCurrentTime.textContent = formatTime(current);
  els.durationTime.textContent = formatTime(duration);
  els.miniDuration.textContent = formatTime(duration);
  els.sideDuration.textContent = formatTime(duration);
  highlightLyric();
}

function updatePlayButtons() {
  const symbol = els.audio.paused ? "▶" : "⏸";
  els.playPauseBtn.textContent = symbol;
  els.detailPlayBtn.textContent = symbol;
}

function playByOffset(offset) {
  if (!state.tracks.length) return;
  const base = state.currentIndex >= 0 ? state.currentIndex : 0;
  const next = (base + offset + state.tracks.length) % state.tracks.length;
  playTrack(state.tracks[next].id);
}

function seekToPercent(percent) {
  if (!Number.isFinite(els.audio.duration)) return;
  els.audio.currentTime = (Number(percent) / 100) * els.audio.duration;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function bindEvents() {
  els.tabs.forEach((tab) => {
    tab.addEventListener("click", () => {
      showPage(tab.dataset.page);
    });
  });

  els.backToLibraryBtn.addEventListener("click", () => showPage("library"));

  [els.nowCard, els.miniPlayer].forEach((entry) => {
    entry.addEventListener("click", (event) => {
      if (!isPlayerControl(event.target)) openPlayerDetail();
    });
    entry.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        openPlayerDetail();
      }
    });
  });

  els.addFolderBtn.addEventListener("click", async () => {
    if (!window.showDirectoryPicker) {
      els.folderInput.click();
      return;
    }
    const handle = await window.showDirectoryPicker({ mode: "read" });
    const folder = {
      id: makeId(),
      name: handle.name,
      handle,
      permission: "已授权",
      trackCount: 0,
    };
    state.folders.push(folder);
    await saveFolder(folder);
    renderFolders();
    await scanFolders();
  });

  els.folderInput.addEventListener("change", async () => {
    const files = Array.from(els.folderInput.files || []);
    if (!files.length) return;
    const firstPath = files[0].webkitRelativePath || files[0].name;
    const rootName = firstPath.includes("/") ? firstPath.split("/")[0] : "已选择文件夹";
    const folder = {
      id: makeId(),
      name: rootName,
      files,
      permission: "本次会话已选择",
      trackCount: 0,
    };
    state.folders.push(folder);
    renderFolders();
    await scanFolders();
    els.folderInput.value = "";
  });

  els.scanFoldersBtn.addEventListener("click", scanFolders);
  els.rescanBtn.addEventListener("click", scanFolders);

  els.clearRecentBtn.addEventListener("click", () => {
    state.recentIds = [];
    localStorage.removeItem("recentTracks");
    renderRecent();
  });

  els.searchInput.addEventListener("input", applySearch);

  els.trackList.addEventListener("click", (event) => {
    const row = event.target.closest("[data-track-id]");
    if (row) playTrack(row.dataset.trackId);
  });

  els.recentList.addEventListener("click", (event) => {
    const row = event.target.closest("[data-track-id]");
    if (row) playTrack(row.dataset.trackId);
  });

  els.folderList.addEventListener("click", async (event) => {
    const removeButton = event.target.closest("[data-folder-remove]");
    if (!removeButton) return;
    const id = removeButton.dataset.folderRemove;
    state.folders = state.folders.filter((folder) => folder.id !== id);
    state.tracks = state.tracks.filter((track) => track.folderId !== id);
    await deleteFolder(id);
    applySearch();
    renderFolders();
  });

  [els.playPauseBtn, els.detailPlayBtn].forEach((button) => {
    button.addEventListener("click", async () => {
      if (!state.currentTrack && state.tracks[0]) {
        await playTrack(state.tracks[0].id);
        return;
      }
      if (els.audio.paused) await els.audio.play();
      else els.audio.pause();
    });
  });

  [els.prevBtn, els.detailPrevBtn].forEach((button) => button.addEventListener("click", () => playByOffset(-1)));
  [els.nextBtn, els.detailNextBtn].forEach((button) => button.addEventListener("click", () => playByOffset(1)));

  [els.seekBar, els.miniSeek, els.sideSeek].forEach((range) => {
    range.addEventListener("input", () => {
      state.isSeeking = true;
      els.seekBar.value = range.value;
      els.miniSeek.value = range.value;
      els.sideSeek.value = range.value;
    });
    range.addEventListener("change", () => {
      seekToPercent(range.value);
      state.isSeeking = false;
    });
  });

  els.audio.addEventListener("timeupdate", updateProgress);
  els.audio.addEventListener("durationchange", updateProgress);
  els.audio.addEventListener("play", updatePlayButtons);
  els.audio.addEventListener("pause", updatePlayButtons);
  els.audio.addEventListener("ended", () => playByOffset(1));
}

async function init() {
  bindEvents();
  renderTracks();
  renderRecent();
  renderFolders();
  updateProgress();
  updatePlayButtons();

  try {
    state.folders = await loadFolders();
    renderFolders();
    if (state.folders.length) await scanFolders();
  } catch (error) {
    console.error(error);
    setStatus("读取文件夹记录失败");
  }
}

init();

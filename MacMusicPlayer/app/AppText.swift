import AppKit

enum AppText {
    // MARK: - 基础应用信息
    static let appName = "Ocean"
    static let exitApp = "退出Ocean"
    
    // MARK: - 侧边栏及导航
    static let sidebarLibrary = "  发 现"
    static let sidebarFolders = "  文 件 夹"
    static let sidebarPlaylists = "  歌 单"
    static let sidebarAddFolder = "选择文件夹"
    static let sidebarRescan = "重新扫描"
    static let backToLibrary = "‹ 返回资料库"
    
    // MARK: - 操作与状态
    static let select = "选择"
    static let addToPlaylist = "加入歌单"
    static let enqueueNext = "加入待播"
    static let defaultStatus = "待播放"
    static let playbackFailed = "播放失败"
    static let clearRecent = "清除最近播放"
    static let play = "播放"
    static let removeSong = "移除歌曲"
    static let noSelection = "未选择"
    static let done = "完成"
    static let findMusic = "发现"
    static let noSongPlaying = "还没有播放歌曲"
    static let importMusicHint = "从文件夹导入音乐开始"
    static let chooseSongHint = "请选择一首歌"
    static let chooseSongDetailHint = "在音乐列表中选择一首歌"
    static let unknownSource = "未选择来源"
    static let zeroDuration = "0:00"
    
    // MARK: - 播放列表页面
    static let noPlaylists = "还没有歌单。点击“新建列表”创建一个。"
    static let selectPlaylist = "选择一个歌单"
    static let newPlaylist = "新建歌单"
    static let deletePlaylist = "删除"
    static let alertAddToPlaylistTitle = "加入歌单"
    static let alertAddToPlaylistMsg = "选择要加入的歌单。"
    static let alertAddButton = "加入"
    static let alertCancelButton = "取消"
    static let alertNewPlaylistTitle = "新建歌单"
    static let alertNewPlaylistMsg = "请输入歌单的名称："
    static let alertCreateButton = "添加"
    static let noMusics = "还没有音乐。前往“文件夹”页面选择本地或 iCloud 文件夹。"
    
    // MARK: - 队列与待播
    static let emptyQueueTip = "从歌曲或歌单开始播放后，将在这里显示待播歌曲。"

    // MARK: - 页面标题与提示
    static let library = "发现"
    static let playlists = "歌单"
    static let folders = "文件夹"
    static let queue = "待播"
    static let songs = "歌曲"
    static let lyrics = "歌词"
    static let recent = "最近播放"
    static let librarySearchPlaceholder = "搜索歌名、艺术家、文件夹"
    static let refreshScan = "刷新"
    static let allFolders = "全部文件夹"
    static let noLyrics = "未找到同名 .lrc 或内嵌歌词"
    static let lyricsFileEmpty = "歌词文件为空"
    static let lyricsExternalHint = "将同名 .lrc 文件放在歌曲旁边，或使用带内嵌歌词的 FLAC。"

    static func trackCount(_ count: Int) -> String { "\(count) 首" }
    static func selectedCount(_ count: Int) -> String { "已选择 \(count) 首" }
    static func loadedTrackCount(_ count: Int) -> String { "已载入 \(count) 首" }
    
    // MARK: - 菜单与显示设置
    static let menuAppearanceSettings = "显示设置"
    static let menuAppearanceSystem = "跟随系统"
    static let menuAppearanceLight = "浅色"
    static let menuAppearanceDark = "深色"
}

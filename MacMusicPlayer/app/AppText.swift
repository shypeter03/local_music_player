import AppKit

enum AppText {
    // MARK: - 基础应用信息
    static let appName = "Ocean"
    static let exitApp = "退出Ocean"
    
    // MARK: - 侧边栏及导航
    static let sidebarLibrary = "音乐列表"
    static let sidebarFolders = "文件夹"
    static let sidebarPlaylists = "播放列表"
    static let sidebarAddFolder = "选择文件夹"
    static let sidebarRescan = "重新扫描"
    static let backToLibrary = "‹ 返回资料库"
    
    // MARK: - 操作与状态
    static let select = "选择"
    static let addToPlaylist = "加入列表"
    static let enqueueNext = "加入待播"
    static let defaultStatus = "待播放"
    static let playbackFailed = "播放失败"
    static let clearRecent = "清除最近播放"
    
    // MARK: - 播放列表页面
    static let noPlaylists = "还没有播放列表。点击“新建列表”创建一个。"
    static let selectPlaylist = "选择一个播放列表"
    static let newPlaylist = "新建列表"
    static let deletePlaylist = "删除列表"
    static let alertAddToPlaylistTitle = "加入播放列表"
    static let alertAddToPlaylistMsg = "选择要加入的列表。"
    static let alertAddButton = "加入"
    static let alertCancelButton = "取消"
    static let alertNewPlaylistTitle = "新建播放列表"
    static let alertNewPlaylistMsg = "请输入新播放列表的名称："
    static let alertCreateButton = "创建"
    
    // MARK: - 队列与待播
    static let emptyQueueTip = "从歌曲列表或播放列表开始播放后，将在这里显示待播歌曲。"
    
    // MARK: - 菜单与显示设置
    static let menuAppearanceSettings = "显示设置"
    static let menuAppearanceSystem = "跟随系统"
    static let menuAppearanceLight = "浅色"
    static let menuAppearanceDark = "深色"
}

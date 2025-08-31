# scripts/autoload/xr_manager.gd
extends Node

enum PlayMode {
    DESKTOP,
    XR
}

var current_mode: PlayMode = PlayMode.DESKTOP
var xr_interface: XRInterface
var is_xr_available: bool = false

func _ready():
    # XRの可用性をチェックするが、まだ初期化しない
    check_xr_availability()
    # デスクトップモードで開始
    ensure_desktop_mode()

func check_xr_availability() -> bool:
    xr_interface = XRServer.find_interface("OpenXR")
    if not xr_interface:
        print("XRManager: OpenXRインターフェースが見つかりません - デスクトップモードで実行")
        is_xr_available = false
        return false
    is_xr_available = true
    
    #print("XRManager: OpenXRインターフェースが利用可能です")
    #var trackers = XRServer.get_trackers(XRServer.TRACKER_HEAD)
    #print("XRManager: ヘッドトラッカーの数: ", trackers.size())
    #var hand_trackers = XRServer.get_trackers(XRServer.TRACKER_CONTROLLER)
    #print("XRManager: コントローラートラッカーの数: ", hand_trackers.size())

    return true

func initialize_xr() -> bool:
    if not is_xr_available:
        print("XRManager: XR利用不可 - デスクトップモードを継続")
        return false

    if not xr_interface.is_initialized():
        if not xr_interface.initialize():
            print("XRManager: OpenXRの初期化に失敗 - デスクトップモードにフォールバック")
            ensure_desktop_mode()
            return false
 
    get_viewport().use_xr = true
    current_mode = PlayMode.XR
    return true

func initialize_desktop_for_seating():
    ensure_desktop_mode()
    print("XRManager: デスクトップモードで seating を開始")

func ensure_desktop_mode():
    print("ensure_desktop_mode: デスクトップモードに切り替え")
    get_viewport().use_xr = false
    current_mode = PlayMode.DESKTOP
    
func is_xr_mode() -> bool:
    return current_mode == PlayMode.XR

func is_desktop_mode() -> bool:
    return current_mode == PlayMode.DESKTOP

func get_play_mode() -> PlayMode:
    return current_mode

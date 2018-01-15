import UIKit
import AVFoundation

extension Notification.Name {
	static let sharedPlayerChanged = Notification.Name(rawValue: "io.objc.sharedPlayerChanged")
}

class SharedPlayer {
	static let shared = SharedPlayer()
	
	var audioPlayer: Player?
	var recording: Recording? {
		didSet {
			if recording === oldValue { return }
			updateForChangedRecording()
		}
	}
	struct PlayerState {
		var progress: TimeInterval
		var duration: TimeInterval
	}
	
	var state: PlayerState = PlayerState(progress: 0, duration: 0) {
		didSet {
			NotificationCenter.default.post(name: .sharedPlayerChanged, object: self, userInfo: [
				"recording": recording as Any,
				"state": state
				])
		}
	}
	
	func updateForChangedRecording() {
		if let r = recording, let store = r.store {
			audioPlayer = Player(url: store.fileURL(for: r)) { [weak self] time in
				if let t = time {
					self?.state.progress = t
				} else {
					self?.recording = nil
				}
			}
			
			if let ap = audioPlayer {
				state = PlayerState(progress: 0, duration: ap.duration)
			} else {
				recording = nil
			}
		} else {
			audioPlayer = nil
			state = PlayerState(progress: 0, duration: 0)
		}
	}

}

class PlayViewController: UIViewController, UITextFieldDelegate, AVAudioPlayerDelegate {
	@IBOutlet weak var nameTextField: UITextField!
	@IBOutlet weak var playButton: UIButton!
	@IBOutlet weak var progressLabel: UILabel!
	@IBOutlet weak var durationLabel: UILabel!
	@IBOutlet weak var progressSlider: UISlider!
	@IBOutlet weak var noRecordingLabel: UILabel!
	@IBOutlet weak var activeItemElements: UIView!

	var recording: Recording? {
		get { return SharedPlayer.shared.recording }
		set { SharedPlayer.shared.recording = newValue }
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
		navigationItem.leftItemsSupplementBackButton = true
		updateForChangedRecording(SharedPlayer.shared.recording, state: SharedPlayer.shared.state)

		NotificationCenter.default.addObserver(self, selector: #selector(storeChanged(notification:)), name: Store.ChangedNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(playerChanged(notification:)), name: .sharedPlayerChanged, object: nil)

	}

	@objc func storeChanged(notification: Notification) {
		guard let item = notification.object as? Item, item === recording else { return }
		updateForChangedRecording(SharedPlayer.shared.recording, state: SharedPlayer.shared.state)
	}
	
	@objc func playerChanged(notification: Notification) {
		guard let r = notification.userInfo?["recording"] as? Recording?,
			let s = notification.userInfo?["state"] as? SharedPlayer.PlayerState else {
				return
		}
		updateForChangedRecording(r, state: s)
	}

	
	func updateForChangedRecording(_ recording: Recording?, state: SharedPlayer.PlayerState) {
		if let r = recording {
			updateProgressDisplays(progress: state.progress, duration: state.duration)
			navigationItem.title = r.name
			nameTextField?.text = r.name
			activeItemElements?.isHidden = false
			noRecordingLabel?.isHidden = true
		} else {
			updateProgressDisplays(progress: 0, duration: 0)
			navigationItem.title = ""
			activeItemElements?.isHidden = true
			noRecordingLabel?.isHidden = false
		}
	}
	
	func updateProgressDisplays(progress: TimeInterval, duration: TimeInterval) {
		progressLabel?.text = timeString(progress)
		durationLabel?.text = timeString(duration)
		progressSlider?.maximumValue = Float(duration)
		progressSlider?.value = Float(progress)
		updatePlayButton()
	}
	
	func updatePlayButton() {
		let audioPlayer = SharedPlayer.shared.audioPlayer
		if audioPlayer?.isPlaying == true {
			playButton?.setTitle(.pause, for: .normal)
		} else if audioPlayer?.isPaused == true {
			playButton?.setTitle(.resume, for: .normal)
		} else {
			playButton?.setTitle(.play, for: .normal)
		}
	}
	
	func textFieldDidEndEditing(_ textField: UITextField) {
		if let r = recording, let text = textField.text {
			r.setName(text)
			navigationItem.title = r.name
		}
	}
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
	
	@IBAction func setProgress() {
		guard let s = progressSlider else { return }
		SharedPlayer.shared.audioPlayer?.setProgress(TimeInterval(s.value))
	}
	
	@IBAction func play() {
		SharedPlayer.shared.audioPlayer?.togglePlay()
		updatePlayButton()
	}
	
	// MARK: UIStateRestoring
	
	override func encodeRestorableState(with coder: NSCoder) {
		super.encodeRestorableState(with: coder)
		coder.encode(recording?.uuidPath, forKey: .uuidPathKey)
	}
	
	override func decodeRestorableState(with coder: NSCoder) {
		super.decodeRestorableState(with: coder)
		if let uuidPath = coder.decodeObject(forKey: .uuidPathKey) as? [UUID], let recording = Store.shared.item(atUuidPath: uuidPath) as? Recording {
			self.recording = recording
		}
	}
}

fileprivate extension String {
	static let uuidPathKey = "uuidPath"
	
	static let pause = NSLocalizedString("Pause", comment: "")
	static let resume = NSLocalizedString("Resume playing", comment: "")
	static let play = NSLocalizedString("Play", comment: "")
}

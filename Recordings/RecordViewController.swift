import UIKit
import AVFoundation

final class RecordViewController: UIViewController, AVAudioRecorderDelegate {
	@IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var stopButton: UIButton!
    
	var audioRecorder: Recorder?
	var folder: Folder? = nil
	var recording = Recording(name: "", uuid: UUID())
	
	override func viewDidLoad() {
		super.viewDidLoad()
		timeLabel.text = timeString(0)
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		audioRecorder = Recorder(url: Store.shared.fileURL(for: recording)) { time in
			if let t = time {
				self.timeLabel.text = timeString(t)
			} else {
				self.dismiss(animated: true)
			}
		}
		if audioRecorder == nil {
			dismiss(animated: true)
		}
	}
	
	@IBAction func stop(_ sender: Any) {
		audioRecorder?.stop()
		modalTextAlert(title: .saveRecording, accept: .save, placeholder: .nameForRecording) { string in
			if let title = string {
				self.recording.name = title
				self.folder?.add(self.recording)
			} else {
				self.recording.deleted()
			}
         self.dismiss(animated: true)
		}
	}
}

fileprivate extension String {
	static let saveRecording = NSLocalizedString("Save recording", comment: "Heading for audio recording save dialog")
	static let save = NSLocalizedString("Save", comment: "Confirm button text for audio recoding save dialog")
	static let nameForRecording = NSLocalizedString("Name for recording", comment: "Placeholder for audio recording name text field")
}

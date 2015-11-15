//
//  DataViewController.swift
//  MemeApp
//
//  Created by ichikawa on 2015/11/14.
//  Copyright © 2015年 xlune.com. All rights reserved.
//

import UIKit
import AVFoundation
import Alamofire

class DataViewController: UIViewController, AVAudioPlayerDelegate {
    
    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var outAngleX: UILabel!
    @IBOutlet weak var outAngleY: UILabel!
    @IBOutlet weak var outAngleZ: UILabel!
    @IBOutlet weak var outPosX: UILabel!
    @IBOutlet weak var outPosY: UILabel!
    @IBOutlet weak var outPosZ: UILabel!
    @IBOutlet weak var outDelta: UILabel!
    
    
    let endPoint = "https://ynzghgnxp0.execute-api.ap-northeast-1.amazonaws.com/dev/gestures"
    let endPointDev = "https://dl.dropboxusercontent.com/u/206795/dummy.json"
    let timeout:Double = 3.0
    var _jsonData : AnyObject!
    var _jsonLoading : Bool = false
    var _gestures : [Gesture]!
//    var _resetCount : Int = 0;
    var _audio : AVAudioPlayer!
    var _sounds : [String:AVAudioPlayer] = [String:AVAudioPlayer]()
    var _preTime : Double = 0.0
    var _v : [Double] = [Double](count: 7, repeatedValue: 0.0)
    var _delta_sum:Double = 0.0
    
    
    /* ジェスチャー */
    struct Gesture {
        var command : [[Int]]
        var command_current : Int
        var sound : String
        var life_count : Int
        var exec_count : Int
        var delta_sum : Double
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.updateJsonData()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        
    }
    
    @IBAction func disconnectAction(sender: UIButton) {
        if MEMELib.sharedInstance().isConnected {
            MEMELib.sharedInstance().disconnectPeripheral()
        }
    }
    
    @IBAction func reloadAction(sender: AnyObject) {
        self.updateJsonData()
    }
    
    func updateJsonData() {
        if self._jsonLoading {
            return
        }
        self._jsonLoading = true
        self._jsonData = nil
        
        Alamofire
            .request(.GET, self.endPointDev)
            .responseJSON { (response) -> Void in
                switch response.result {
                case .Success:
                    print(">>> Validation Successful")
                    self._jsonData = response.result.value
                    self._gestures = []
                    let gestures = self._jsonData["gestures"] as! [[String:AnyObject!]]
                    for gesture in gestures {
                        let command = gesture["command"] as! [[Int]]
                        let soundKey = gesture["sound"] as! String
                        let g = Gesture(
                            command: command,
                            command_current: 0,
                            sound: soundKey,
                            life_count: gesture["life_count"] as! Int,
                            exec_count: 0,
                            delta_sum: 0.0
                        )
                        self._gestures.append(g)
                        self._sounds[soundKey] = self.prepareSound(soundKey)
                    }
                case .Failure(let error):
                    print(error)
                }
                self._jsonLoading = false
        }
    }

    func prepareSound(path: String) -> (AVAudioPlayer) {
        let audioPath = NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource(path, ofType: "mp3")!)
        let audioPlayer = try! AVAudioPlayer(contentsOfURL: audioPath)
        //        audioPlayer.delegate = self
        audioPlayer.prepareToPlay()
        return audioPlayer;
        
    }
    
    func memeRealTimeModeDataReceived(data: MEMERealTimeData!) {
        if self._jsonData != nil {
            let seconds = NSDate.timeIntervalSinceReferenceDate()
            let now:Double = seconds //* 1000
            if self._preTime == 0.0 {
                self._preTime = now
                self._v[0] = Double(data.pitch)
                self._v[1] = Double(data.yaw)
                self._v[2] = Double(data.roll)
                self._v[3] = Double(data.accX)
                self._v[4] = Double(data.accY)
                self._v[5] = Double(data.accZ)
            }

            let deltaTime = now - self._preTime
            var v:[Double] = [Double](count: 7, repeatedValue: 0.0)
            v[0] = (Double(data.pitch) - self._v[0]) / deltaTime
            v[1] = (Double(data.yaw)   - self._v[1]) / deltaTime //TODO: 360問題
            v[2] = (Double(data.roll)  - self._v[2]) / deltaTime
            v[3] = (Double(data.accX)  - self._v[3]) / deltaTime
            v[4] = (Double(data.accY)  - self._v[4]) / deltaTime
            v[5] = (Double(data.accZ)  - self._v[5]) / deltaTime
            v[6] = deltaTime
            
            self._preTime = now
            self._v[0] = Double(data.pitch)
            self._v[1] = Double(data.yaw)
            self._v[2] = Double(data.roll)
            self._v[3] = Double(data.accX)
            self._v[4] = Double(data.accY)
            self._v[5] = Double(data.accZ)
            self._delta_sum += deltaTime
            
            self.outAngleX.text = String(v[0])
            self.outAngleY.text = String(v[1])
            self.outAngleZ.text = String(v[2])
            self.outPosX.text   = String(v[3])
            self.outPosY.text   = String(v[4])
            self.outPosZ.text   = String(v[5])
            self.outDelta.text  = String(v[6])
            
            for var i = 0; i<self._gestures.count; i++ {
                var g = self._gestures[i]
                //回数制限
                if g.life_count > 0 && g.exec_count >= g.life_count {
                    continue;
                }
                let tg = g.command[g.command_current]
                let tt = tg[0]
                let tv = tg[1]
                var cv = v[tt]
                if tt == 6 {
                    cv += g.delta_sum
                    g.delta_sum = cv
                }

                //達成判定
                if self.isOverValue(cv, tgVal: Double(tv)) {
                    g.delta_sum = 0.0
                    if ++g.command_current >= g.command.count {
                        //全て達成
                        //リセット
                        g.command_current = 0
                        g.delta_sum = 0.0
                        self.resetAllGestures()
                        //play
                        self._sounds[g.sound]!.play()
                        g.exec_count += 1
                    }
                }
                //更新
                self._gestures[i] = g
            }

            //タイムアウトリセット
            if self._delta_sum > self.timeout {
                //reset
                self.resetAllGestures()
            }
        }
    }
    
    func resetAllGestures() {
        for var i = 0; i<self._gestures.count; i++ {
            var g = self._gestures[i]
            g.command_current = 0
            g.delta_sum = 0.0
            self._gestures[i] = g
        }
        self._delta_sum = 0.0
    }
    
    func isOverValue(currentVal:Double, tgVal:Double) -> Bool {
        if tgVal < 0 {
            return currentVal <= tgVal
        } else {
            return currentVal >= tgVal
        }
    }
}

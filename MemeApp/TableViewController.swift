//
//  TableViewController.swift
//  MemeApp
//
//  Created by ichikawa on 2015/11/14.
//  Copyright © 2015年 xlune.com. All rights reserved.
//

import UIKit
import AVFoundation

class TableViewController: UITableViewController, MEMELibDelegate {
    
    @IBOutlet weak var reloadButton: UIBarButtonItem!
    var _loadingButton: UIBarButtonItem!
    var _activityIndicator: UIActivityIndicatorView!
    var _peripherals: [CBPeripheral] = [CBPeripheral]()
    var _dataViewController: DataViewController!
    
    var _audio : AVAudioPlayer!

    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        if _loadingButton == nil {
            _activityIndicator = UIActivityIndicatorView(frame: CGRectMake(0, 0, 20, 20))
            _activityIndicator.color = UIColor.blackColor()
            _loadingButton = UIBarButtonItem(customView: _activityIndicator)
        }
        
        MEMELib.sharedInstance().delegate = self
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func loadView() {
        super.loadView()
        //イベント設定
        NSNotificationCenter.defaultCenter().removeObserver(self)
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "onUpdateDevices",
            name: "test1",//BluetoothManager.EVENT_SCAN_UPDATE,
            object: nil
        )
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "onScanDevices",
            name: "test2", //BluetoothManager.EVENT_SCAN_STATE_CHANGE,
            object: nil
        )
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "DataViewSegue" {
            self._dataViewController = segue.destinationViewController as! DataViewController
        }
    }
    
    // MARK: - EventListener
    func onUpdateDevices() {
        //テーブル表示更新
        self.tableView?.reloadData()
    }
    
    func onScanDevices() {
//        reloadButton.enabled = !bleManager.scanActive
//        if bleManager.scanActive {
//            _activityIndicator.startAnimating()
//            self.setToolbarItems([_loadingButton], animated: true)
//            self.navigationItem.rightBarButtonItem = _loadingButton
//        }else{
//            
//            self.setToolbarItems([reloadButton], animated: true)
//            self.navigationItem.rightBarButtonItem = reloadButton
//            _activityIndicator.stopAnimating()
//        }
        
    }
    
    // MARK: - Action
    @IBAction func reloadAction(sender: UIBarButtonItem!) {
        
//        bleManager.startScan()
        let status = MEMELib.sharedInstance().startScanningPeripherals()
        self.checkMemeStatus(status)
        
    }
    
    // MARK: - Delegate
    // セクション数
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    // Cell選択イベント
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        print("Num: \(indexPath.row)")
        
        let peripheral = self._peripherals[indexPath.row]
        let status = MEMELib.sharedInstance().connectPeripheral(peripheral)
        
        self.checkMemeStatus(status)
        
        
        //接続するペリフェラルを指定
//        bleManager.peripheral = bleManager.peripherals[indexPath.row]
        
        //ページ遷移
//        self.performSegueWithIdentifier("bleRead", sender: self)
    }
    
    // Cellの総数
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        return bleManager.peripherals.count
        return self._peripherals.count
    }
    
    // Cellの表示設定
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {

        var cell = tableView.dequeueReusableCellWithIdentifier("DeviceListCellIdentifier")
        if cell == nil {
            cell = UITableViewCell.init(style: UITableViewCellStyle.Default, reuseIdentifier: "DeviceListCellIdentifier")
        }
        
        let peripheral = self._peripherals[indexPath.row]
        cell?.textLabel?.text = peripheral.identifier.UUIDString
        return cell!
    }

    
//MARK: - MEME
    func memeAppAuthorized(status: MEMEStatus) {
        self.checkMemeStatus(status)
    }
    
    func memePeripheralFound(peripheral: CBPeripheral!, withDeviceAddress address: String!) {
        for p in self._peripherals {
            if p.identifier.isEqual(peripheral.identifier) {
                return
            }
        }
        print("New peripheral found \(peripheral.identifier.UUIDString) \(address)")
        self._peripherals.append(peripheral)
        self.tableView.reloadData()
    }
    
    func memePeripheralConnected(peripheral: CBPeripheral!) {
        
        print("MEME Device Connected!");
        
        self.reloadButton.enabled = false
        self.tableView.userInteractionEnabled = false
        
        switch MEMELib.sharedInstance().isCalibrated {
        case CALIB_NOT_FINISHED:
            print("CALIB_NOT_FINISHED")
            break
        case CALIB_BODY_FINISHED:
            print("CALIB_BODY_FINISHED")
            break
        case CALIB_EYE_FINISHED:
            print("CALIB_EYE_FINISHED")
            break
        case CALIB_BOTH_FINISHED:
            print("CALIB_BOTH_FINISHED")
            break
        default:
            print("CALIB_NONE")
            break
        }
        
        
        //view遷移
        self.performSegueWithIdentifier("DataViewSegue", sender: self)
        //[self performSegueWithIdentifier:@"DataViewSegue" sender: self];
        
        // Set Data Mode to Standard Mode
        let status = MEMELib.sharedInstance().startDataReport()
        print(status)
    }
    
    func memePeripheralDisconnected(peripheral: CBPeripheral!) {
        print("MEME Device Disconnected");
        
        self.reloadButton.enabled = true
        self.tableView.userInteractionEnabled = true
        
        //View削除
        self.dismissViewControllerAnimated(true) { () -> Void in
            self._dataViewController = nil
        }
    }
    
    func memeRealTimeModeDataReceived(data: MEMERealTimeData!) {
        if self._dataViewController != nil {
            self._dataViewController.memeRealTimeModeDataReceived(data)
        }
    }
    
    func memeCommandResponse(response: MEMEResponse) {
        print("Command Response - eventCode: 0x%02x - commandResult: %d", response.eventCode, response.commandResult);
        
        switch (response.eventCode) {
        case 0x02:
            print("Data Report Started");
            break;
        case 0x04:
            print("Data Report Stopped");
            break;
        default:
            break;
        }
    }
    
    func checkMemeStatus(status: MEMEStatus!) {
//        var ac: UIAlertController = UIAlertController.init()
//        let ac = UIAlertController(
//            title: "Error",
//            message: "Bluetooth is off.",
//            preferredStyle: .Alert)

        if status == MEME_OK {
            print("MEME_OK")
            return
        } else if status == MEME_ERROR_APP_AUTH {
            print("MEME_ERROR_APP_AUTH")
//            ac = UIAlertController(
//                title: "App Auth Failed",
//                message: "Invalid Application ID or Client Secret",
//                preferredStyle: .Alert)
            
        } else if status == MEME_ERROR_SDK_AUTH {
            print("MEME_ERROR_SDK_AUTH")
//            ac = UIAlertController(
//                title: "SDK Auth Failed",
//                message: "Invalid SDK. Please update to the latest SDK.",
//                preferredStyle: .Alert)
        } else if status == MEME_CMD_INVALID {
            print("MEME_CMD_INVALID")
//            ac = UIAlertController(
//                title: "SDK Error",
//                message: "Invalid Command",
//                preferredStyle: .Alert)
        } else if status == MEME_ERROR_BL_OFF {
            print("MEME_ERROR_BL_OFF")
//            ac = UIAlertController(
//                title: "Error",
//                message: "Bluetooth is off.",
//                preferredStyle: .Alert)
        }
        
//        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel) { (action) -> Void in
//            print("Cancel button tapped.")
//        }
//        
//        let okAction = UIAlertAction(title: "OK", style: .Default) { (action) -> Void in
//            print("OK button tapped.")
//        }
        
//        ac.addAction(cancelAction)
//        ac.addAction(okAction)
//        self.presentViewController(ac, animated: true, completion: nil)
        
    }

}



// MARK: - Private Class

//class PeripheralViewCell : UITableViewCell {
//    var peripheral: CBPeripheral?
//    
//    func update(peripheral: CBPeripheral) {
//        self.peripheral = peripheral;
//        self.refresh()
//    }
//    
//    func refresh() {
//        self.textLabel!.text = self.peripheral?.name
//    }
//}



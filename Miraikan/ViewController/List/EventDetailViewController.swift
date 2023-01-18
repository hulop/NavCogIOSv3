//
//
//  EventDetailViewController.swift
//  NavCogMiraikan
//
/*******************************************************************************
 * Copyright (c) 2022 © Miraikan - The National Museum of Emerging Science and Innovation  
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *******************************************************************************/

import Foundation

class EventDetailViewController : BaseController {

    private let eventDetailView: EventDetailView
    private let scheduleRowModel: ScheduleRowModel

    private var isObserved : Bool = false
    
    private let PREV_MINS = 5

    init(model: ScheduleRowModel, title: String) {
        eventDetailView = EventDetailView(model)
        scheduleRowModel = model
        super.init(eventDetailView, title: title)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        eventDetailView.navigationAction = { [weak self] in
            guard let self = self else { return }
            self.startNavi()
        }

        eventDetailView.notificationAction = { [weak self] in
            guard let self = self else { return }
            self.setNotification()
        }
    }

    private func startNavi() {
        if self.isObserved { return }
        self.isObserved = true
        let toID = scheduleRowModel.floorMap.nodeId
        guard let nav = self.navigationController as? BaseNavController else { return }
        nav.openMap(nodeId: toID)
        self.isObserved = false
    }

    private func setNotification() {
        if self.isObserved { return }
        self.isObserved = true

        let schedule = scheduleRowModel.schedule
        if schedule.place == "co_studio" {
            let scheduledTime = schedule.time.split(separator: ":")
            
            if scheduledTime.indices.contains(1),
                let hour = Int(scheduledTime[0]),
                let minute = Int(scheduledTime[1]) {

                let calendar = Calendar(identifier: .gregorian)
                let today = Date()

                if let scheduleDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) {
                    if scheduleDate < today {
                        let alert = UIAlertController(title: nil, message: NSLocalizedString("Today's event is over", comment: ""), preferredStyle: .alert)
                        let yesAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default)
                        alert.addAction(yesAction)
                        present(alert, animated: true, completion: nil)
                    } else if let preDate = calendar.date(byAdding: .minute, value: -PREV_MINS, to: scheduleDate) {
                        if preDate < today {
                            let alert = UIAlertController(title: nil, message: NSLocalizedString("It will start soon. Please head to the venue", comment: ""), preferredStyle: .alert)
                            let yesAction = UIAlertAction(title: NSLocalizedString("YES", comment: ""), style: .default) { action in
                                self.startNavi()
                            }
                            let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: ""), style: .cancel)
                            alert.addAction(yesAction)
                            alert.addAction(cancelAction)
                            present(alert, animated: true, completion: nil)
                        } else {
                            let alert = UIAlertController(title: nil, message: NSLocalizedString("Do you want to be notified before the event starts?", comment: ""), preferredStyle: .alert)
                            let yesAction = UIAlertAction(title: NSLocalizedString("YES", comment: ""), style: .default) { action in
                                self.setLocalNotification(date: scheduleDate, notificationDate: preDate)
                            }
                            let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: ""), style: .cancel)
                            alert.addAction(yesAction)
                            alert.addAction(cancelAction)
                            present(alert, animated: true, completion: nil)
                        }
                    }
                }
            }
        }
        self.isObserved = false
    }

    private func setLocalNotification(date: Date, notificationDate: Date) {
        let schedule = scheduleRowModel.schedule

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Join the Co-Studio Talk", comment: "")
        guard let talkTitle = ExhibitionDataStore.shared.events?
            .first(where: { $0.id == schedule.event })?.talkTitle
        else { return }
        content.body = "\(talkTitle)"

        var title: String?
        var nodeId: String?
        if let floorMaps = MiraikanUtil.readJSONFile(filename: "floor_map",
                                                     type: [FloorMapModel].self) as? [FloorMapModel],
           let floorMap = floorMaps.first(where: {$0.id == schedule.place }) {
            title = floorMap.title
            nodeId = floorMap.nodeId
        }
        content.userInfo = [
            "date": date,
            "eventId": schedule.event,
            "nodeId": nodeId ?? "",
            "facilityId": schedule.place,
            "title": title ?? ""
        ]

        let calendar = Calendar(identifier: .gregorian)
        
        let components = calendar.dateComponents(
            [Calendar.Component.hour, Calendar.Component.minute],
             from: notificationDate)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components,
                                                    repeats: false)
        let request = UNNotificationRequest(identifier: schedule.event,
                                            content: content,
                                            trigger: trigger)

        UNUserNotificationCenter.current().add(request, withCompletionHandler: { error in
            if let _err = error {
                print(_err.localizedDescription)
            }
        })
    }
}

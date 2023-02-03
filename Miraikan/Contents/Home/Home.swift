//
//  Home.swift
//  NavCogMiraikan
//
/*******************************************************************************
 * Copyright (c) 2021 © Miraikan - The National Museum of Emerging Science and Innovation
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
import UIKit


/**
 Customized UITableViewCell for Special Exhibition or Event
 */
fileprivate class CardRow : BaseRow {
    // Default image
    private var img = UIImage(named: "card_loading")!
    // image cache
    private var url: URL?
    
    // Global variables
    private var isOnline = false
    
    // Views
    private let imgView = UIImageView()
    private let lblTitle = AutoWrapLabel()
    private let lblPlace = AutoWrapLabel()
    
    // Sizing
    private let gapX: CGFloat = 10
    private let gapY: CGFloat = 10
    private let imgAdaptor = ImageAdaptor()
    
    // MARK: init
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.backgroundColor = .systemBackground
        self.accessibilityTraits = .button
        lblTitle.font = .preferredFont(forTextStyle: .body)
        lblPlace.font = .preferredFont(forTextStyle: .body)
        addSubview(imgView)
        addSubview(lblTitle)
        addSubview(lblPlace)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /**
     Set data from DataSource
     */
    public func configure(_ model: CardModel, owner: UITableView?) {
        
        // Set the data and flag
        if let url = URL(string: "\(Host.miraikan.address)\(model.imagePc)") {
            if self.url != nil,
               self.url == url  {
                return
            }
            imgView.image = nil
            URLSession.shared.dataTask(with: url) { [weak self] (data, res, error) in
                guard let data = data else { return }
                guard error == nil else { return }
                let image = UIImage(data: data)
                self?.url = url

                DispatchQueue.main.async {
                    self?.onFetchedImage(image: image,
                                         table: owner)
                }
            }.resume()
        } else {
            if let img = UIImage(named: "card_not_available") {
                imgView.image = img
            }
        }

        lblTitle.text = model.title
        if let _isOnline = model.isOnline {
            self.isOnline = !_isOnline.isEmpty
        }
        
        if self.isOnline {
            lblPlace.text = NSLocalizedString("place_online", comment: "")
        } else {
            lblPlace.text = ""
        }
        layoutSubviews()
    }

    func onFetchedImage(image: UIImage?, table: UITableView?) {
        imgView.image = image
        if let indexPath = table?.indexPath(for: self) {
            table?.reloadRows(at: [indexPath], with: .none)
        }
    }
    
    // MARK: layout
    override func layoutSubviews() {
        super.layoutSubviews()
        let halfWidth = CGFloat(frame.width / 2)
        
        let scaledSize = imgAdaptor.scaleImage(viewSize: ImageType.CARD.size,
                                               frameWidth: halfWidth - insets.left - gapX * 2,
                                               imageSize: img.size)
        imgView.frame = CGRect(x: insets.left + gapX,
                               y: insets.top + gapY,
                               width: scaledSize.width,
                               height: scaledSize.height)
        let szFit = CGSize(width: halfWidth - insets.right - gapX, height: innerSize.height)
        lblTitle.frame = CGRect(x: halfWidth,
                                y: insets.top + gapY,
                                width: halfWidth - insets.right - gapX,
                                height: lblTitle.sizeThatFits(szFit).height)
        if isOnline {
            lblPlace.frame = CGRect(x: halfWidth,
                                    y: insets.top + lblTitle.frame.height + gapY,
                                    width: halfWidth - insets.right,
                                    height: lblPlace.sizeThatFits(szFit).height)
        }
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let halfWidth = CGFloat(size.width / 2)
        let scaledSize = imgAdaptor.scaleImage(viewSize: ImageType.CARD.size,
                                               frameWidth: halfWidth - insets.left - gapX * 2,
                                               imageSize: img.size)
        let heightLeft = insets.top + scaledSize.height
        let szFit = CGSize(width: halfWidth - insets.right - gapX, height: size.height)
        var heightList = [lblTitle.sizeThatFits(szFit).height]
        if isOnline {
            heightList += [lblPlace.sizeThatFits(szFit).height,
                           gapY]
        }
        let heightRight = heightList.reduce((insets.top + insets.bottom), { $0 + $1 })
        let height = max(heightLeft, heightRight) + gapY * 2
        return CGSize(width: size.width, height: height)
    }
}

/**
 Customized UITableViewCell for menu items
 */
fileprivate class MenuRow : BaseRow {
    
    private let btnItem = ChevronButton()
    
    public var title: String? {
        didSet {
            btnItem.setTitle(title, for: .normal)
            btnItem.sizeToFit()
        }
    }
    
    public var isAvailable : Bool? {
        didSet {
            guard let isAvailable = isAvailable else {
                return
            }
            
            if isAvailable {
                btnItem.setTitleColor(.black, for: .normal)
                btnItem.imageView?.tintColor = .black
                btnItem.accessibilityLabel = title
            } else {
                self.selectionStyle = .none
                btnItem.setTitleColor(.gray, for: .normal)
                btnItem.imageView?.tintColor = .gray
                btnItem.accessibilityLabel = NSLocalizedString("blank_description", comment: "")
            }
        }
    }
    
    // MARK: init
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        // To prevent the button being selected on VoiceOver
        self.backgroundColor = .systemBackground
        btnItem.isEnabled = false
        // "Disabled" would not be read out
        btnItem.accessibilityTraits = .button
        addSubview(btnItem)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: layout
    override func layoutSubviews() {
        super.layoutSubviews()
        btnItem.frame = CGRect(origin: CGPoint(x: insets.bottom, y: insets.top),
                               size: btnItem.sizeThatFits(innerSize))
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let innerSz = innerSizing(parentSize: size)
        let height = insets.top + insets.bottom + btnItem.sizeThatFits(innerSz).height
        return CGSize(width: size.width, height: height)
    }
}

fileprivate class NewsRow : BaseRow {
    
    private let btnItem = ChevronButton()
    
    public var title: String? {
        didSet {
            btnItem.setTitle(title, for: .normal)
            btnItem.sizeToFit()
        }
    }
    
    public var isAvailable : Bool? {
        didSet {
            guard let isAvailable = isAvailable else {
                return
            }
            
            if isAvailable {
                btnItem.setTitleColor(.black, for: .normal)
                btnItem.imageView?.tintColor = .black
                btnItem.accessibilityLabel = title
            } else {
                self.selectionStyle = .none
                btnItem.setTitleColor(.gray, for: .normal)
                btnItem.imageView?.tintColor = .gray
                btnItem.accessibilityLabel = NSLocalizedString("blank_description", comment: "")
            }
        }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.backgroundColor = .systemBackground
        btnItem.isEnabled = false
        btnItem.accessibilityTraits = .button
        addSubview(btnItem)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        btnItem.frame = CGRect(origin: CGPoint(x: insets.bottom, y: insets.top),
                               size: btnItem.sizeThatFits(innerSize))
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let innerSz = innerSizing(parentSize: size)
        let height = insets.top + insets.bottom + btnItem.sizeThatFits(innerSz).height
        return CGSize(width: size.width, height: height)
    }
    
}

/**
 The menu items for the home screen
 */
fileprivate enum MenuItem {
    case login
    case miraikanToday
    case permanentExhibition
    case currentPosition
    case arNavigation
    case reservation
    case suggestion
    case floorMap
    case nearestWashroom
    case setting
    case miraikanIDmyPage
    case aboutMiraikan
    case aboutApp
    
    var isAvailable: Bool {
        let availableItems : [MenuItem] = [
            .login,
            .miraikanToday,
            .permanentExhibition,
            .currentPosition,
            .arNavigation,
            .floorMap,
            .nearestWashroom,
            .setting,
            .miraikanIDmyPage,
            .aboutMiraikan,
            .aboutApp
        ]
        return availableItems.contains(self)
    }
    
    var name : String {
        switch self {
        case .login:
            return NSLocalizedString("Login", comment: "")
        case .miraikanToday:
            return NSLocalizedString("Miraikan Today", comment: "")
        case .permanentExhibition:
            return NSLocalizedString("Permanent Exhibitions", comment: "")
        case .reservation:
            return NSLocalizedString("Reservation", comment: "")
        case .currentPosition:
            return NSLocalizedString("Current Position", comment: "")
        case .arNavigation:
            return NSLocalizedString("AR navigation", comment: "")
        case .suggestion:
            return NSLocalizedString("Suggested Routes", comment: "")
        case .floorMap:
            return NSLocalizedString("Floor Plan", comment: "")
        case .nearestWashroom:
            return NSLocalizedString("Neareast Washroom", comment: "")
        case .setting:
            return NSLocalizedString("Settings", comment: "")
        case .miraikanIDmyPage:
            return NSLocalizedString("Miraikan ID My Page", comment: "")
        case .aboutMiraikan:
            return NSLocalizedString("About Miraikan", comment: "")
        case .aboutApp:
            return NSLocalizedString("About This App", comment: "")
        }
    }

    /**
     Create the UIViewController MenuItem is tapped.
     By default it ret
     
     - Returns:
     A specific UIViewController, or BaseViewController with BaseView by default
     */
    func createVC() -> UIViewController {
        switch self {
        case .login:
            return createVC(view: LoginView())
        case .permanentExhibition:
            return PermanentExhibitionController(title: self.name)
        case .miraikanToday:
            return EventListController(title: self.name)
        case .nearestWashroom:
            return RestRoomListViewController(title: "")
        case .arNavigation:
            return ARViewController()
        case .setting:
            return NaviSettingController(title: NSLocalizedString("Navi Settings", comment: ""))
        case .miraikanIDmyPage:
            return createVC(view: MiraikanIDMyPageView())
        case .floorMap:
            return createVC(view: WebFloorMapView())
        case .aboutMiraikan:
            return createVC(view: AboutMiraikanView())
        case .aboutApp:
            return createVC(view: AboutAppView())
        default:
            return createVC(view: BaseView())
        }
    }

    // Default method to create a UIViewController
    private func createVC(view: UIView) -> UIViewController {
        return BaseController(view, title: self.name)
    }
}

/**
 The menu secitons for the home screen
 */
fileprivate enum MenuSection : CaseIterable {
    case login
    case spex
    case event
    case exhibition
    case currentLocation
    case arNavigation
    case reservation
    case suggestion
    case map
    case settings

    var items: [MenuItem]? {
        switch self {
        case .login:
            return [.login]
        case .exhibition:
            return [.miraikanToday, .permanentExhibition]
        case .currentLocation:
            return [.currentPosition]
        case .arNavigation:
            return [.arNavigation]
        case .reservation:
            return [.reservation]
        case .suggestion:
            return [.suggestion]
        case .map:
            return [.floorMap, .nearestWashroom]
        case .settings:
            return [.setting, .miraikanIDmyPage, .aboutMiraikan, .aboutApp]
        default:
            return nil
        }
    }

    var endpoint: String? {
        let lang = NSLocalizedString("lang", comment: "")
        // Caution: data are not fully available for other languages than Japanese.
        switch self {
        case .spex:
            return "/exhibitions/spexhibition/_assets/json/\(lang).json"
        case .event:
            let year = MiraikanUtil.calendar().component(.year, from: Date())
            return "/events/_assets/json/\(year)/\(lang).json"
        default:
            return nil
        }
    }

    var title: String? {
        switch self {
        case .spex:
            return NSLocalizedString("spex", comment: "")
        case .event:
            return NSLocalizedString("Events", comment: "")
        case .exhibition:
            return NSLocalizedString("museum_info", comment: "")
        default:
            return nil
        }
    }
}

/**
 The BaseListView (TableView) for the Home screen
 */
class Home : BaseListView {
    private let menuCellId = "menuCell"
    private let cardCellId = "cardCell"
    private let newsCellId = "newsCell"
    
    private var sections: [MenuSection]?
    
    override func initTable(isSelectionAllowed: Bool) {
        // init the tableView
        super.initTable(isSelectionAllowed: true)

        self.tableView.register(BaseRow.self, forCellReuseIdentifier: menuCellId)
        self.tableView.register(CardRow.self, forCellReuseIdentifier: cardCellId)
        self.tableView.register(NewsRow.self, forCellReuseIdentifier: newsCellId)
        
        setSection()
        setHeaderFooter()
    }

    func setSection() {
        // load the data
        sections = MenuSection.allCases
        if MiraikanUtil.isLoggedIn {
            sections?.removeAll(where: { $0 == .login })
        }
        
        guard let _sections = sections?.enumerated() else { return }
        
        let httpAdaptor = HTTPAdaptor()
        var menuItems = [Int : [Any]]()
        for (idx, sec) in _sections {
            if let _items = sec.items {
                menuItems[idx] = _items
            } else if let _endpoint = sec.endpoint {
                menuItems[idx] = []
                httpAdaptor.http(endpoint: _endpoint, success: { [weak self] data in
                    guard let self = self else { return }
                    
                    guard let res = MiraikanUtil.decdoeToJSON(type: [CardModel].self, data: data)
                    else { return }
//                    NSLog("\(URL(string: #file)!.lastPathComponent) \(#function): \(#line), \(_endpoint)")
                    let filtered = res.filter({ model in
                        let now = Date()
                        let start = MiraikanUtil.parseDate(model.start)!
                        let end = MiraikanUtil.parseDate(model.end)!
                        let endOfDay = MiraikanUtil.calendar().date(byAdding: .day, value: 1, to: end)!
                        return start <= now && endOfDay >= now
                    })
                    menuItems[idx] = filtered
                    self.items = menuItems
                })
            } else {
                menuItems[idx] = []
            }
        }
        items = menuItems
    }

    private func setHeaderFooter() {
        let headerView = UIView (frame: CGRect(x: 0, y: 0, width: self.frame.width, height: CGFloat.leastNonzeroMagnitude))
        self.tableView.tableHeaderView = headerView

        let footerView = UIView (frame: CGRect(x: 0, y: 0, width: self.frame.width, height: 90.0))
        self.tableView.tableFooterView = footerView
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        tableView.frame = CGRect(x: insets.left,
                                 y: insets.top,
                                 width: innerSize.width,
                                 height: innerSize.height)
    }

    // MARK: UITableViewDataSource
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let (sec, row) = (indexPath.section, indexPath.row)
        
        if let items = (items as? [Int: [Any]])?[sec], items.isEmpty {
            let cell = UITableViewCell()
            cell.textLabel?.textColor = .lightGray
            cell.selectionStyle = .none
            switch sections?[sec] {
            case .spex:
                cell.textLabel?.text = NSLocalizedString("no_spex", comment: "")
            case .event:
                cell.textLabel?.text = NSLocalizedString("no_event", comment: "")
            default:
                print("Empty Section")
            }
            return cell
        } else {
            let rowItem = (items as? [Int: [Any]])?[sec]?[row]
            if let menuItem = rowItem as? MenuItem {
               let menuRow = tableView.dequeueReusableCell(withIdentifier: menuCellId, for: indexPath)
                // Normal Menu Row
                let attrStr = NSMutableAttributedString()
                attrStr.append(NSAttributedString(string:(menuItem.name)))
                
                if let image = UIImage(systemName: "chevron.right") {
                    let attachment = NSTextAttachment(image: image)
                    attrStr.append(NSAttributedString(string: " "))
                    attrStr.append(NSAttributedString(attachment: attachment))
                }
                menuRow.textLabel?.attributedText = attrStr
                menuRow.textLabel?.font = .preferredFont(forTextStyle: .body)
                menuRow.textLabel?.isEnabled = menuItem.isAvailable
                menuRow.selectionStyle = menuItem.isAvailable ? .default : .none
                menuRow.accessibilityLabel = menuItem.isAvailable ? menuItem.name : NSLocalizedString("blank_description", comment: "")
                menuRow.accessibilityTraits = .button

                return menuRow
            } else if let cardModel = rowItem as? CardModel,
                      let cardRow = tableView.dequeueReusableCell(withIdentifier: cardCellId,
                                                                  for: indexPath) as? CardRow {
                // When HTTP request is finished,
                // display the data on the row for Special Exhibition or Event
                cardRow.configure(cardModel, owner: tableView)
                return cardRow
            } else if let news = rowItem as? String,
                      let newsRow = tableView.dequeueReusableCell(withIdentifier: newsCellId,
                                                                  for: indexPath) as? NewsRow {
                newsRow.title = "・\(news)"
                newsRow.isAvailable = false
                return newsRow
            }
        }
        
        return UITableViewCell()
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections?[section].title
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        view.tintColor = .systemGray
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = .white
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if sections?[section] == .spex
                    || sections?[section] == .event,
            let items = (items as? [Int : [Any]])?[section] {
            return items.count > 0 ? items.count : 1
        } else if let rows = (items as? [Int: [Any]])?[section] {
            return rows.count
        }
        
        return 0
    }

    // MARK: UITableViewDelegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let nav = navVC else { return }
        let (sec, row) = (indexPath.section, indexPath.row)
        let rowItem = (items as? [Int: [Any]])?[sec]?[row]
        
        if let menuItem = rowItem as? MenuItem,
            menuItem.isAvailable {
            if menuItem == .currentPosition {
                guard let nav = self.navVC else { return }
                AudioGuideManager.shared.floorPlan()
                nav.openMap(nodeId: nil)
            } else {
                let vc = menuItem.createVC()
                nav.show(vc, sender: nil)
            }
        } else if let cardModel = rowItem as? CardModel {
            let view = ExhibitionView(permalink: cardModel.permalink)
            nav.show(BaseController(view, title: cardModel.title), sender: nil)
        }
        super.tableView(tableView, didSelectRowAt: indexPath)
    }
}

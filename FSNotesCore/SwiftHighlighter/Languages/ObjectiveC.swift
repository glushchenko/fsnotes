//
//  ObjectiveCLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct ObjectiveCLanguage: LanguageDefinition {
    let name = "Objective-C"
    let aliases: [String]? = ["objc", "objective-c", "objectivec", "obj-c", "m", "mm"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = [
        "keyword": [
            // C keywords
            "auto", "break", "case", "char", "const", "continue", "default", "do",
            "double", "else", "enum", "extern", "float", "for", "goto", "if",
            "inline", "int", "long", "register", "restrict", "return", "short",
            "signed", "sizeof", "static", "struct", "switch", "typedef", "union",
            "unsigned", "void", "volatile", "while",
            // Objective-C keywords
            "@interface", "@implementation", "@protocol", "@end", "@private",
            "@protected", "@public", "@package", "@property", "@synthesize",
            "@dynamic", "@class", "@selector", "@encode", "@defs", "@synchronized",
            "@try", "@catch", "@throw", "@finally", "@autoreleasepool",
            "@optional", "@required",
            // Memory management
            "retain", "release", "autorelease", "dealloc", "alloc", "init",
            "copy", "mutableCopy",
            // Modern Objective-C
            "strong", "weak", "unsafe_unretained", "assign", "nonatomic", "atomic",
            "readonly", "readwrite", "getter", "setter", "nullable", "nonnull",
            "null_resettable", "null_unspecified", "_Nullable", "_Nonnull",
            "_Null_unspecified",
            // Special
            "self", "super", "_cmd", "id", "Class", "SEL", "IMP", "BOOL",
            "YES", "NO", "nil", "Nil", "NULL",
            // Type qualifiers
            "in", "out", "inout", "bycopy", "byref", "oneway",
            // Blocks
            "__block", "__weak", "__strong", "__unsafe_unretained", "__autoreleasing",
            // ARC
            "__bridge", "__bridge_retained", "__bridge_transfer",
            // Availability
            "__deprecated", "__unavailable", "__attribute__",
            // Other
            "instancetype", "typeof", "__typeof__"
        ],
        "literal": ["YES", "NO", "nil", "Nil", "NULL", "true", "false"],
        "built_in": [
            // Foundation - Basic types
            "NSObject", "NSString", "NSMutableString", "NSNumber", "NSValue",
            "NSData", "NSMutableData", "NSDate", "NSCalendar", "NSDateComponents",
            "NSTimeZone", "NSLocale", "NSURL", "NSURLComponents", "NSURLRequest",
            "NSMutableURLRequest", "NSURLResponse", "NSHTTPURLResponse",
            "NSURLSession", "NSURLSessionTask", "NSURLSessionDataTask",
            "NSURLSessionDownloadTask", "NSURLSessionUploadTask",
            // Foundation - Collections
            "NSArray", "NSMutableArray", "NSDictionary", "NSMutableDictionary",
            "NSSet", "NSMutableSet", "NSOrderedSet", "NSMutableOrderedSet",
            "NSIndexSet", "NSMutableIndexSet", "NSEnumerator", "NSFastEnumeration",
            "NSIndexPath", "NSPointerArray", "NSHashTable", "NSMapTable",
            // Foundation - Text processing
            "NSAttributedString", "NSMutableAttributedString", "NSScanner",
            "NSCharacterSet", "NSMutableCharacterSet", "NSRegularExpression",
            "NSTextCheckingResult", "NSDataDetector", "NSFormatter",
            "NSNumberFormatter", "NSDateFormatter", "NSByteCountFormatter",
            "NSLengthFormatter", "NSMassFormatter", "NSEnergyFormatter",
            // Foundation - Errors
            "NSError", "NSException", "NSAssertionHandler",
            // Foundation - File system
            "NSFileManager", "NSFileHandle", "NSFileWrapper", "NSBundle",
            "NSProcessInfo", "NSUserDefaults", "NSNotificationCenter",
            "NSNotification", "NSNotificationQueue",
            // Foundation - Threading
            "NSThread", "NSRunLoop", "NSOperation", "NSOperationQueue",
            "NSBlockOperation", "NSInvocationOperation", "NSCondition",
            "NSConditionLock", "NSLock", "NSRecursiveLock", "NSDistributedLock",
            // Foundation - Run loop
            "NSTimer", "NSPort", "NSPortMessage",
            // Foundation - Archiving
            "NSKeyedArchiver", "NSKeyedUnarchiver", "NSCoder", "NSArchiver",
            "NSUnarchiver", "NSPropertyListSerialization",
            // Foundation - JSON
            "NSJSONSerialization", "NSJSONReadingOptions", "NSJSONWritingOptions",
            // Foundation - KVO/KVC
            "NSKeyValueObserving", "NSKeyValueCoding",
            // Foundation - Predicates
            "NSPredicate", "NSCompoundPredicate", "NSComparisonPredicate",
            "NSExpression",
            // Foundation - Sort descriptors
            "NSSortDescriptor",
            // Foundation - UUID
            "NSUUID",
            // Foundation - Other
            "NSNull", "NSProxy", "NSInvocation", "NSMethodSignature",
            "NSUndoManager", "NSCache", "NSPurgeableData", "NSProgress",
            // UIKit - View Controllers
            "UIViewController", "UINavigationController", "UITabBarController",
            "UITableViewController", "UICollectionViewController",
            "UISplitViewController", "UIPageViewController", "UISearchController",
            "UIAlertController", "UIActivityViewController", "UIPopoverPresentationController",
            // UIKit - Views
            "UIView", "UIWindow", "UILabel", "UIButton", "UITextField",
            "UITextView", "UIImageView", "UIScrollView", "UITableView",
            "UICollectionView", "UIPickerView", "UIDatePicker", "UISwitch",
            "UISlider", "UIStepper", "UISegmentedControl", "UIProgressView",
            "UIActivityIndicatorView", "UIWebView", "WKWebView", "UIStackView",
            "UIVisualEffectView", "UIToolbar", "UINavigationBar", "UITabBar",
            "UISearchBar", "UIPageControl", "UIRefreshControl",
            // UIKit - Cells
            "UITableViewCell", "UICollectionViewCell", "UITableViewHeaderFooterView",
            // UIKit - Layout
            "NSLayoutConstraint", "NSLayoutAnchor", "UILayoutGuide",
            "UIEdgeInsets", "CGRect", "CGPoint", "CGSize", "CGFloat", "CGAffineTransform",
            // UIKit - Graphics
            "UIColor", "UIImage", "UIFont", "UIBezierPath", "CALayer",
            "CAShapeLayer", "CAGradientLayer", "CATextLayer", "CAScrollLayer",
            "CAReplicatorLayer", "CATransformLayer", "CAEmitterLayer",
            "CATiledLayer",
            // UIKit - Gestures
            "UIGestureRecognizer", "UITapGestureRecognizer", "UIPinchGestureRecognizer",
            "UIRotationGestureRecognizer", "UISwipeGestureRecognizer",
            "UIPanGestureRecognizer", "UIScreenEdgePanGestureRecognizer",
            "UILongPressGestureRecognizer",
            // UIKit - Animation
            "UIViewPropertyAnimator", "CAAnimation", "CABasicAnimation",
            "CAKeyframeAnimation", "CAAnimationGroup", "CATransition",
            "CASpringAnimation", "UIViewAnimating",
            // UIKit - Other
            "UIApplication", "UIApplicationDelegate", "UIScreen", "UIDevice",
            "UIResponder", "UIEvent", "UITouch", "UIPasteboard", "UIMenuController",
            "UIPrintInteractionController", "UIDocumentInteractionController",
            "UIDocumentPickerViewController",
            // Core Graphics
            "CGContext", "CGPath", "CGImage", "CGColor", "CGColorSpace",
            "CGGradient", "CGPattern", "CGFont", "CGPDFDocument", "CGPDFPage",
            // Core Animation
            "CADisplayLink", "CAMediaTiming", "CAMediaTimingFunction",
            // Dispatch (GCD)
            "dispatch_queue_t", "dispatch_group_t", "dispatch_semaphore_t",
            "dispatch_source_t", "dispatch_block_t", "dispatch_once_t",
            "dispatch_async", "dispatch_sync", "dispatch_after", "dispatch_once",
            "dispatch_get_main_queue", "dispatch_get_global_queue",
            "dispatch_queue_create", "dispatch_group_create", "dispatch_semaphore_create",
            // Core Data
            "NSManagedObject", "NSManagedObjectContext", "NSManagedObjectModel",
            "NSPersistentStoreCoordinator", "NSPersistentStore", "NSFetchRequest",
            "NSEntityDescription", "NSAttributeDescription", "NSRelationshipDescription",
            "NSFetchedResultsController", "NSPersistentContainer",
            // Core Location
            "CLLocationManager", "CLLocation", "CLLocationCoordinate2D",
            "CLPlacemark", "CLGeocoder", "CLRegion", "CLCircularRegion",
            "CLBeaconRegion", "CLHeading", "CLVisit",
            // MapKit
            "MKMapView", "MKAnnotation", "MKAnnotationView", "MKPinAnnotationView",
            "MKPointAnnotation", "MKPolyline", "MKPolygon", "MKCircle",
            "MKOverlay", "MKOverlayRenderer", "MKDirections", "MKRoute",
            // AVFoundation
            "AVPlayer", "AVPlayerItem", "AVPlayerLayer", "AVAsset", "AVURLAsset",
            "AVAudioPlayer", "AVAudioRecorder", "AVAudioSession",
            "AVCaptureDevice", "AVCaptureSession", "AVCaptureInput", "AVCaptureOutput",
            // StoreKit
            "SKProduct", "SKProductsRequest", "SKPayment", "SKPaymentQueue",
            "SKPaymentTransaction", "SKStoreProductViewController",
            // Social/Contacts
            "CNContact", "CNContactStore", "CNContactPickerViewController",
            "CNMutableContact", "CNLabeledValue",
            // UserNotifications
            "UNUserNotificationCenter", "UNNotificationRequest", "UNNotificationContent",
            "UNMutableNotificationContent", "UNNotificationTrigger",
            // Other frameworks
            "NSLayoutManager", "NSTextContainer", "NSTextStorage",
            "UICollectionViewLayout", "UICollectionViewFlowLayout"
        ]
    ]
    let contains: [Mode] = [
        Mode(scope: "comment", begin: "/\\*", end: "\\*/"),
        Mode(scope: "comment", begin: "//", end: "\n"),
        Mode(scope: "meta", begin: "^\\s*#\\s*(?:import|include|define|undef|if|ifdef|ifndef|else|elif|endif|error|pragma|warning)\\b.*$"),

        Mode(scope: "keyword", begin: "@(?:interface|implementation|protocol|end|class|selector|encode|property|synthesize|dynamic|try|catch|throw|finally|synchronized|autoreleasepool|optional|required)\\b"),
        
        Mode(scope: "class", begin: "@interface\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        Mode(scope: "class", begin: "@protocol\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        Mode(scope: "class", begin: "@implementation\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        
        Mode(scope: "function", begin: "^\\s*[-+]\\s*\\([^)]+\\)\\s*[a-zA-Z_][a-zA-Z0-9_:]*"),
        
        // Selectors
        Mode(scope: "meta", begin: "@selector\\s*\\(", end: "\\)"),
        
        // NSString literals
        Mode(scope: "string", begin: "@\"", end: "\""),
        
        // C strings
        CommonModes.stringDouble,
        
        // Character literals
        Mode(scope: "string", begin: "'(?:[^'\\\\]|\\\\.)+'"),
        
        // NSNumber literals
        Mode(scope: "number", begin: "@(?:\\d+\\.?\\d*|0[xX][0-9a-fA-F]+|YES|NO)\\b"),
        
        // Array literals
        Mode(scope: "meta", begin: "@\\[", end: "\\]"),
        
        // Dictionary literals
        Mode(scope: "meta", begin: "@\\{", end: "\\}"),
        
        // Blocks
        Mode(scope: "function", begin: "\\^\\s*(?:\\([^)]*\\))?\\s*\\{", end: "\\}"),
        
        // Hex
        Mode(scope: "number", begin: "\\b0[xX][0-9a-fA-F]+[uUlL]*\\b"),
        // Octal
        Mode(scope: "number", begin: "\\b0[0-7]+[uUlL]*\\b"),
        // Float/Double
        Mode(scope: "number", begin: "\\b\\d+\\.\\d+[fFlL]?\\b"),
        Mode(scope: "number", begin: "\\b\\d+[eE][+-]?\\d+[fFlL]?\\b"),
        Mode(scope: "number", begin: "\\b\\d+\\.\\d+[eE][+-]?\\d+[fFlL]?\\b"),
        // Integer
        Mode(scope: "number", begin: "\\b\\d+[uUlL]*\\b"),
    ]
}

import Foundation
import HealthKit

enum BreathingState {
    case none
    case holdIn
    case breatheIn
    case holdOut
    case breatheOut
    
    var message: String {
        switch self {
        case .none: return ""
        case .holdIn: return "Hold"
        case .breatheIn: return "Breathe In"
        case .holdOut: return "Hold"
        case .breatheOut: return "Release"
        }
    }
    
    var tapsPerSecond: Int {
        switch self {
        case .none: return 0
        case .holdIn, .holdOut: return 4
        case .breatheIn, .breatheOut: return 2
        }
    }
}

class HeartRateManager: ObservableObject {
    private var healthStore = HKHealthStore()
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var breathingTimer: Timer?
    private let breathingStateInterval: TimeInterval = 4.0 // 4 seconds per state
    
    @Published var currentHeartRate: Double = 0
    @Published var isAuthorized = false
    @Published var isMonitoring = false
    @Published var breathingState: BreathingState = .none
    @Published var isBreathingExerciseActive = false
    
    init() {
        requestAuthorization()
    }
    
    func requestAuthorization() {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        healthStore.requestAuthorization(toShare: [], read: [heartRateType]) { success, error in
            DispatchQueue.main.async {
                self.isAuthorized = success
                if success {
                    self.startHeartRateMonitoring()
                }
            }
        }
    }
    
    func startHeartRateMonitoring() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        // Stop any existing query
        stopHeartRateMonitoring()
        
        let query = HKAnchoredObjectQuery(type: heartRateType,
                                        predicate: nil,
                                        anchor: nil,
                                        limit: HKObjectQueryNoLimit) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }
        
        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }
        
        heartRateQuery = query
        healthStore.execute(query)
        
        DispatchQueue.main.async {
            self.isMonitoring = true
        }
    }
    
    func stopHeartRateMonitoring() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
        
        stopBreathingExercise()
        
        DispatchQueue.main.async {
            self.isMonitoring = false
            self.currentHeartRate = 0
        }
    }
    
    func toggleMonitoring() {
        if isMonitoring {
            stopHeartRateMonitoring()
        } else {
            startHeartRateMonitoring()
        }
    }
    
    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample] else { return }
        
        DispatchQueue.main.async {
            guard let mostRecentSample = heartRateSamples.last else { return }
            let heartRate = mostRecentSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            self.currentHeartRate = heartRate
            
            // Check if we need to start or stop breathing exercise
            if heartRate >= 100 && !self.isBreathingExerciseActive {
                self.startBreathingExercise()
            } else if heartRate < 100 && self.isBreathingExerciseActive {
                self.stopBreathingExercise()
            }
        }
    }
    
    private func startBreathingExercise() {
        isBreathingExerciseActive = true
        breathingState = .breatheIn
        
        breathingTimer?.invalidate()
        breathingTimer = Timer.scheduledTimer(withTimeInterval: breathingStateInterval, repeats: true) { [weak self] _ in
            self?.updateBreathingState()
        }
    }
    
    private func stopBreathingExercise() {
        breathingTimer?.invalidate()
        breathingTimer = nil
        isBreathingExerciseActive = false
        breathingState = .none
    }
    
    private func updateBreathingState() {
        switch breathingState {
        case .none:
            breathingState = .breatheIn
        case .breatheIn:
            breathingState = .holdIn
        case .holdIn:
            breathingState = .breatheOut
        case .breatheOut:
            breathingState = .holdOut
        case .holdOut:
            breathingState = .breatheIn
        }
    }
} 

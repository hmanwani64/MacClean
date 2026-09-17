import Foundation
import Darwin
import IOKit.ps

/// Reads basic system health info (CPU load, memory usage, battery level)
/// using macOS's own built-in APIs — no special permissions required.
struct SystemMonitorService {
    static let shared = SystemMonitorService()

    func currentStats() -> SystemStats {
        SystemStats(
            cpuUsagePercent: cpuUsage(),
            memoryUsedBytes: memoryUsed(),
            memoryTotalBytes: Int64(ProcessInfo.processInfo.physicalMemory),
            batteryPercent: batteryPercent()
        )
    }

    /// Samples CPU load twice, a moment apart, and compares the difference —
    /// that's how "current" CPU usage is measured on macOS.
    private func cpuUsage() -> Double {
        func sample() -> host_cpu_load_info? {
            var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
            var info = host_cpu_load_info()
            let result = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
                ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                    host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPtr, &count)
                }
            }
            return result == KERN_SUCCESS ? info : nil
        }

        guard let first = sample() else { return 0 }
        Thread.sleep(forTimeInterval: 0.15)
        guard let second = sample() else { return 0 }

        let userDiff = Double(second.cpu_ticks.0 &- first.cpu_ticks.0)
        let sysDiff = Double(second.cpu_ticks.1 &- first.cpu_ticks.1)
        let idleDiff = Double(second.cpu_ticks.2 &- first.cpu_ticks.2)
        let niceDiff = Double(second.cpu_ticks.3 &- first.cpu_ticks.3)

        let totalDiff = userDiff + sysDiff + idleDiff + niceDiff
        guard totalDiff > 0 else { return 0 }
        let busy = userDiff + sysDiff + niceDiff
        return min(100, max(0, (busy / totalDiff) * 100))
    }

    private func memoryUsed() -> Int64 {
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var stats = vm_statistics64()
        let result = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        let pageSize = Int64(vm_kernel_page_size)
        let used = Int64(stats.active_count + stats.wire_count + stats.compressor_page_count) * pageSize
        return used
    }

    /// Returns nil on Macs with no battery (e.g. a Mac mini or Mac Studio).
    private func batteryPercent() -> Int? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return nil }
        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        guard let firstSource = sources.first else { return nil }
        guard let description = IOPSGetPowerSourceDescription(snapshot, firstSource)?.takeUnretainedValue() as? [String: Any] else { return nil }
        return description[kIOPSCurrentCapacityKey] as? Int
    }
}

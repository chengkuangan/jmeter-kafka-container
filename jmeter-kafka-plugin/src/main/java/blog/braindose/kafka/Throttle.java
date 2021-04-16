package blog.braindose.kafka;

public class Throttle {
    
    private long throttleSizeRate;   // bytes per second
    private int throttleMessageRate;
    private long startMs;
    private long sleepMs = 0;
    private final double MIN_LAG_RATIO = 0.05; 
    private final int MIN_BYTE_INCREMENTAL = 100; 
    private int originalRecordSize;
    
    /**
     * Contrstor to create Throttle object
     * @param startMs Performance test start time in millisecond.
     * @param throttleSizeRate Throttle size rate limit in MB per second
     * @param throttleMessageRate Throttle message number rate limit in messages per second
     */
    public Throttle(int throttleSizeRate, int throttleMessageRate){
        this.startMs = System.currentTimeMillis();
        this.throttleMessageRate = throttleMessageRate;
        this.throttleSizeRate = (long) (throttleSizeRate * 1024 * 1024); //  convert MB to bytes
    }

    private boolean isThrottleSizeRate(){
        return (this.throttleSizeRate > 0);
    }

    private boolean isThrottleMessageRate(){
        return (this.throttleMessageRate > 0);
    }

    private boolean isThrottle(){
        return (isThrottleSizeRate() || isThrottleMessageRate());
    }

    public int getKeepUpSize(double averageSizeRate, double averageMessageRate, int recordSize){
        int size = recordSize;
        if (this.originalRecordSize == 0)   this.originalRecordSize = recordSize;
        if (isUnderThrottleLimitThresshold(averageSizeRate, averageMessageRate)){
            this.sleepMs = 0;
            size += MIN_BYTE_INCREMENTAL;
            //System.out.println("under -> size = " + size);
        }
        else{
            size -= MIN_BYTE_INCREMENTAL;
            if (size <= this.originalRecordSize){
                size = this.originalRecordSize;
            }
            //System.out.println("over -> size = " + size);
        }
        return size;
    }

    public void throttle(double averageSizeRate, double averageMessageRate){
        if (isExceededThrottleLimit(averageSizeRate, averageMessageRate)){
            try{
                synchronized(this){
                    
                    determineSleepMs(averageSizeRate, averageMessageRate);

                    if (this.sleepMs > 0){
                        Thread.sleep(this.sleepMs);
                    }
                }
            }
            catch(InterruptedException e){
                
            }
        }
    }

    private void determineSleepMs(double averageSizeRate, double averageMessageRate){
        if (isThrottleSizeRate() || isThrottleMessageRate()){
            this.sleepMs++;
        }
        else if (!isThrottleSizeRate() && !isThrottleMessageRate()){
            if (this.sleepMs > 0)   this.sleepMs--;
            else this.sleepMs = 0;
        }        
    }

    private boolean isExceededThrottleLimit(double averageSizeRate, double averageMessageRate){
        if (!isThrottle()){
            return false;
        }
        
        //System.out.println("averageSizeRate = " + averageSizeRate + ", throttleSizeRate = " + this.throttleSizeRate);

        if (isThrottleSizeRate()){
            return (averageSizeRate >= this.throttleSizeRate);
        }
        else{
            return (averageMessageRate >= this.throttleMessageRate);
        }
    }

    private boolean isUnderThrottleLimitThresshold(double averageSizeRate, double averageMessageRate){
        if (!isThrottle()){
            return false;
        }

        if (averageSizeRate == 0 && averageMessageRate == 0) return false;
        
        if (isThrottleSizeRate()){
            double gap = (this.throttleSizeRate - averageSizeRate);
            //return gap <= 0 ? false : (gap / this.throttleSizeRate) >= MIN_LAG_RATIO;
            return gap <= 0;
        }
        else{
            double gap = (this.throttleMessageRate - averageMessageRate);
            //return gap <= 0 ? false : (gap / this.throttleMessageRate) >= MIN_LAG_RATIO;
            return gap <= 0;
        }
    }

}

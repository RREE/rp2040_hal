--
--  Copyright 2021 (C) Jeremy Grosser
--
--  SPDX-License-Identifier: BSD-3-Clause
--
with RP2040_SVD.Interrupts; use RP2040_SVD.Interrupts;
with RP2040_SVD.RESETS;     use RP2040_SVD.RESETS;
with RP2040_SVD.TIMER;      use RP2040_SVD.TIMER;
with Cortex_M_SVD.NVIC;     use Cortex_M_SVD.NVIC;
with System.Machine_Code;

package body RP.Timer is
   function Clock
      return Time
   is
      Next_High : UInt32;
      High      : UInt32;
      Low       : UInt32;
   begin
      High := TIMER_Periph.TIMERAWH;
      loop
         --  If TIMERAWH changed while we were reading TIMERAWL, try again
         Low := TIMER_Periph.TIMERAWL;
         Next_High := TIMER_Periph.TIMERAWH;
         exit when Next_High = High;
         High := Next_High;
      end loop;
      return Time (Shift_Left (UInt64 (High), 32) or UInt64 (Low));
   end Clock;

   procedure TIMER_IRQ_2_Handler is
   begin
      TIMER_Periph.INTR.ALARM_2 := True;
   end TIMER_IRQ_2_Handler;

   procedure Enable
      (This : in out Delays)
   is
   begin
      TIMER_Periph.INTE.ALARM_2 := True;
      NVIC_Periph.NVIC_ICPR := Shift_Left (1, TIMER_IRQ_2_Interrupt);
      NVIC_Periph.NVIC_ISER := Shift_Left (1, TIMER_IRQ_2_Interrupt);
   end Enable;

   procedure Disable
      (This : in out Delays)
   is
   begin
      TIMER_Periph.INTE.ALARM_2 := False;
   end Disable;

   function Enabled
      (This : Delays)
      return Boolean
   is (TIMER_Periph.INTE.ALARM_2);

   procedure Delay_Until
      (T : Time)
   is
   begin
      TIMER_Periph.ALARM2 := UInt32 (T and 16#FFFFFFFF#);
      loop
         System.Machine_Code.Asm ("wfi", Volatile => True);
         if Clock >= T then
            return;
         elsif TIMER_Periph.INTS.ALARM_2 then
            --  If the high byte of the timer rolled over but we still haven't
            --  reached the target time, reset the alarm and go again
            TIMER_Periph.ALARM2 := UInt32 (T and 16#FFFFFFFF#);
         end if;
      end loop;
   end Delay_Until;

   overriding
   procedure Delay_Microseconds
      (This : in out Delays;
       Us   : Integer)
   is
      T : constant UInt32 := TIMER_Periph.TIMERAWL + UInt32 (Us);
   begin
      TIMER_Periph.ALARM2 := T;
      loop
         System.Machine_Code.Asm ("wfi", Volatile => True);
         exit when TIMER_Periph.INTS.ALARM_2 or TIMER_Periph.TIMERAWL >= T;
      end loop;
   end Delay_Microseconds;

   overriding
   procedure Delay_Milliseconds
      (This : in out Delays;
       Ms   : Integer)
   is
   begin
      for I in 1 .. Ms loop
         Delay_Microseconds (This, 1_000);
      end loop;
   end Delay_Milliseconds;

   overriding
   procedure Delay_Seconds
      (This : in out Delays;
       S    : Integer)
   is
   begin
      for I in 1 .. S loop
         Delay_Microseconds (This, 1_000_000);
      end loop;
   end Delay_Seconds;
end RP.Timer;

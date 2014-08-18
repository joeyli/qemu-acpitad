    Scope (\_SB.PCI0)
    {   
        Device (TIME)
        {   
            Name (_HID, "ACPI000E")

            Name (MDAY, Buffer (0x18)
            {
            /* Normal years */    31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31,
            /* Leap years   */    31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
            })

            /* CMOS memory access */
            OperationRegion (CMS, SystemIO, 0x70, 0x02)
            Field (CMS, ByteAcc, NoLock, Preserve)
            {
                CMSI,   8,
                CMSD,   8
            }

            IndexField (CMSI, CMSD, ByteAcc, NoLock, Preserve)
            {
                Offset (0x00),
                CSEC,   8,
                Offset (0x02),
                CMIN,   8,
                Offset (0x04),
                CHOU,   8,
                Offset (0x06),
                CWDA,   8,
                Offset (0x07),
                CDAY,   8,
                Offset (0x08),
                CMON,   8,
                Offset (0x09),
                CYEA,   8,
                Offset (0x3b),
		CDST,	8,
                Offset (0x3e),
		CTZL,	8,
                Offset (0x3f),
		CTZH,	8
            }

            Method (CMRD, 1, NotSerialized)
            {
                Store (Arg0, CMSI)
                Store (CMSD, Local0)
                Return (Local0)
            }

            Method (DE2H, 1, NotSerialized)
            {
                If (LGreater (Arg0,0))
                {
                  Divide (Arg0, 16, Local1, Local0)
                  Add (Multiply(Local0, 10), Local1, Local2)
                }
                Return (Local2)
            }

            Method (HE2D, 1, NotSerialized)
            {
                If (LGreater(Arg0,0))
                {
                  Divide (Arg0, 10, Local1, Local0)
                  Add (Multiply(Local0, 16), Local1, Local2)
                }
                Return (Local2)
            }

            Method (YCEN, 1, NotSerialized)
            {
                Store (DE2H(Arg0), Local0)
                If (LGreaterEqual (Local0, 0x5A))
                {
                    Return (Add (0x76C, Local0))
                }
                Else
                {
                    Return (Add (0x7D0, Local0))
                }
            }

            Method (YEAC, 2, NotSerialized)
            {
                // CENT YEAR to CMOS YEAR
                Name (YERH, Zero)
                Name (YERL, Zero)
                Store (Arg0, YERL)
                Store (Arg1, YERH)
                Add (Multiply(YERH, 0x100), YERL, Local0)	// transfer to double bytes

                If (LGreaterEqual (Local0, 0x7D0))
                {
                  Return (Subtract(Local0, 0x7D0))
                }
                Else
                {
                  Return (Subtract(Local0, 0x76C))
                }
            }

            Method (LEAY, 2, NotSerialized)
            {
                Name (YERH, Zero)
                Name (YERL, Zero)
                Store (Arg0, YERL)
                Store (Arg1, YERH)

                Add (Multiply(YERH, 0x100), YERL, Local0)	// transfer to double bytes

                // ((year) % 4 == 0 && ((year) % 100 != 0 || (year) % 400 == 0))
                Store (LEqual (Mod (Local0, 4), 0), Local1)
                Store (LNotEqual (Mod (Local0, 100), 0), Local2)
                Store (LEqual (Mod (Local0, 400), 0), Local3)

                Return (LAnd (Local1, LOr (Local2, Local3)))
            }

            Method (GTZB, 2, NotSerialized)
            {
              Name (TZL, Zero)
              Name (TZH, Zero)
              Name (TZB, Buffer (0x03)
              {
                0x00, 0x00, 0x00
              })
              CreateField (TZB, Zero, 16, TZ)   // Unsigned Timezone
              CreateByteField (TZB, 0x02, TZS)  // Sign of Timezone

              Store (Arg0, TZL)
              Store (Arg1, TZH)

              Add (Multiply(TZH, 0x100), TZL, TZ)

              // two's complement, check sign of TZ
              If (LGreater(TZ, 0x5A0))
              { 
                Subtract (TZ, 1, TZ)
                Not (TZ, TZ)
                And (TZ, 0xFFFF, TZ)
		If (LLessEqual(TZ, 1440))
                {
                  Store (1, TZS)   // indicate value of timezone is negative
                }
                Else
                {
                  Store (2047, TZ)
                }
              }

              Return (TZB)
            }

            Method (E2TZ, 1, NotSerialized)		// Transfer minutes east of UTC to ACPI TZ 
	    {
              CreateByteField (Arg0, 0x0a, TZL)
              CreateByteField (Arg0, 0x0b, TZH)

              Name (TZB, Buffer (0x03)
              {
                0x00, 0x00, 0x00
              })
              CreateField (TZB, Zero, 16, TZ)   // Unsigned Timezone
              CreateByteField (TZB, Zero, UTZL)
              CreateByteField (TZB, 0x01, UTZH) 
              CreateByteField (TZB, 0x02, TZS)  // Sign of Timezone

              Store (GTZB(CTZL, CTZH), TZB) 	// Set sign of Timezone
              
	      //reverse sign of mintes east for chnage to ACPI TZ
	      If (LAnd(LNotEqual(TZ, 0x7FF), LEqual(TZS, 0)))     // positive means in east of UTC
	      {			
		Add (Not (TZ, TZ), 1, TZ)
	      }

	      Store (UTZH, TZH)
	      Store (UTZL, TZL)
	    }

            Method (TZ2E, 1, NotSerialized)		// Transfer ACPI TZ to minutes east of UTC
	    {
              CreateByteField (Arg0, 0x0a, TZL)
              CreateByteField (Arg0, 0x0b, TZH)

              Name (TZB, Buffer (0x03)
              {
                0x00, 0x00, 0x00
              })
              CreateField (TZB, Zero, 16, TZ)   // Unsigned Timezone
              CreateByteField (TZB, Zero, UTZL)
              CreateByteField (TZB, 0x01, UTZH) 
              CreateByteField (TZB, 0x02, TZS)  // Sign of Timezone

              Store (GTZB(TZL, TZH), TZB) 	// Set sign of Timezone
              
	      //reverse sign of ACPI TZ for change to mintes east
	      If (LAnd(LNotEqual(TZ, 0x7FF), LEqual(TZS, 0)))     // for ACPI TZ, positive means in west of UTC
	      {			
		Add (Not (TZ, TZ), 1, TZ)
	      }

	      Store (UTZH, CTZH)		// set to CMOS
	      Store (UTZL, CTZL)
	    }

            Method (INCT, 2, NotSerialized)
            {
              CreateByteField (Arg0, Zero, YERL)
              CreateByteField (Arg0, 0x01, YERH)
              CreateByteField (Arg0, 0x02, MON)
              CreateByteField (Arg0, 0x03, DAY)
              CreateByteField (Arg0, 0x04, HOUR)
              CreateByteField (Arg0, 0x05, MIN)
              CreateByteField (Arg0, 0x06, SEC)
              CreateByteField (Arg0, 0x07, VAL)
              CreateByteField (Arg0, 0x08, MILS)
              CreateByteField (Arg0, 0x0a, TZL)
              CreateByteField (Arg0, 0x0b, TZH)
              CreateField (Arg1, Zero, 16, TZ)
              CreateByteField (Arg1, 0x02, TZS)

              Name (LMDA, Zero)         // Latest day of month
              Name (YEAR, Zero)         // Year

              // handle minutes increase
              Divide (TZ, 60, Local1, Local0)
              Add (HOUR, Local0, HOUR)
              If (LGreater (Local1, 0))
              { 
                If (LGreaterEqual (Add (MIN, Local1, MIN), 60))
                {
                  Subtract (MIN, 60, MIN)
                  Add (HOUR, 1, HOUR)
                }
              }

              If (LGreaterEqual(HOUR, 24))
              {
                Subtract (HOUR, 24, HOUR)
                Add (DAY, 1, DAY)

                // is leap year
                Subtract (MON, 1, Local2)
                If (LEAY (YERL, YERH))
                {
                  Add (Local2, 12, Local2)
                }
                Store (DeRefOf (Index (MDAY, Local2)), LMDA)

                // handle MONTH increase
                If (LGreater (DAY, LMDA))
                { 
                  Subtract (DAY, LMDA, DAY)
                  Add (MON, 1, MON)

                  // handle YEAR increase
                  If (LGreater (MON, 12))
                  {
                    Subtract (MON, 12, MON)
                    Add (Multiply(YERH, 0x100), YERL, YEAR)
                    Add (YEAR, 1, YEAR)
                    ShiftRight(YEAR, 8, YERH)
                    Store (YEAR, YERL)
                  }
                }
              }
            }

            Method (DECT, 2, NotSerialized)
            {
              CreateByteField (Arg0, Zero, YERL)
              CreateByteField (Arg0, 0x01, YERH)
              CreateByteField (Arg0, 0x02, MON)
              CreateByteField (Arg0, 0x03, DAY)
              CreateByteField (Arg0, 0x04, HOUR)
              CreateByteField (Arg0, 0x05, MIN)
              CreateByteField (Arg0, 0x06, SEC)
              CreateByteField (Arg0, 0x07, VAL)
              CreateByteField (Arg0, 0x08, MILS)
              CreateByteField (Arg0, 0x0a, TZL)
              CreateByteField (Arg0, 0x0b, TZH)
              CreateByteField (Arg0, 0x0c, DST)
              CreateField (Arg1, Zero, 16, TZ)
              CreateByteField (Arg1, 0x02, TZS)

              Name (LMDA, Zero)         // Latest day of month
              Name (YEAR, Zero)         // Year

              // handle minutes decrease
              Divide (TZ, 60, Local1, Local0)
              If (LGreater (Local1, 0))
              {
                      If (LGreater (Local1, MIN))
                      {
                        Subtract (Local1, MIN, MIN)
                        Add (Local0, 1, Local0)		// Local0 is the hour should decrease
                      }
                      Else
                      {
                        Subtract (MIN, Local1, MIN)
                      }
              }

              // handle hour decrease
              If (LGreaterEqual(HOUR, Local0))
              {
                Subtract (HOUR, Local0, HOUR)
              }
              Else
              { 
                Subtract (24, Subtract (Local0, HOUR), HOUR)

                // handle day decrease
                If (LEqual(DAY, 1))
                { 
                  If (LLessEqual(MON, 1))
                  {
                    // to the latest day of last year
                    Store (12, MON)
                    Store (31, DAY)

                    // handle year decrease
                    Add (Multiply(YERH, 0x100), YERL, YEAR)
                    Subtract (YEAR, 1, YEAR)
                    ShiftRight(YEAR, 8, YERH)
                    Store (YEAR, YERL)
                  }
                  Else
                  {
                    Subtract (MON, 1, MON)
                    Subtract (MON, 1, Local2)    // latest day of last month
                    If (LEAY (YERL, YERH))      // is leap year
                    {
                      Add (Local2, 12, Local2)
                    }
                    Store (DeRefOf (Index (MDAY, Local2)), DAY)
                  }
                }
                Else
                {
                  Subtract (DAY, 1, DAY)
                }
              }
            }

            Method (UT2L, 1, NotSerialized)
            { 
              CreateByteField (Arg0, 0x0a, TZL)
              CreateByteField (Arg0, 0x0b, TZH)

              Name (TZB, Buffer (0x03)
              {
                0x00, 0x00, 0x00
              })
              CreateField (TZB, Zero, 16, TZ)   // Unsigned Timezone
              CreateByteField (TZB, 0x02, TZS)  // Sign of Timezone

              Store (GTZB(TZL, TZH), TZB)	// Set sign of Timezone

              // Localtime = UTC - TimeZone
              If (LNotEqual (TZ, 2047))
              { 
                If (LEqual(TZS, 1))     // negative TZ means in east of UTC
                {
                  INCT (Arg0, TZB)        // Increate time base on timezone
                }
                Else                    // TZ is in west of UTC
                {
                  DECT (Arg0, TZB)        // Decreate time base on timezone
                }
              }
            }

            Method (LT2U, 1, NotSerialized)
            { 
              CreateByteField (Arg0, 0x0a, TZL)
              CreateByteField (Arg0, 0x0b, TZH)

              Name (TZB, Buffer (0x03)
              {
                0x00, 0x00, 0x00
              })
              CreateField (TZB, Zero, 16, TZ)   // Unsigned Timezone
              CreateByteField (TZB, 0x02, TZS)  // Sign of Timezone

              Store (GTZB(TZL, TZH), TZB)  // Set sign of Timezone

              // Localtime = UTC - TimeZone
              If (LNotEqual (TZ, 2047))
              { 
                If (LEqual(TZS, 1))           // TZ is in east of UTC
                {
                  DECT (Arg0, TZB)        // Decreate time base on timezone
                }
                Else
                {
                  INCT (Arg0, TZB)        // Increate time base on timezone
                }
              }
            }

            Name (_GCP, 0x00000004)
            Mutex (MCTX, 0x00)

            Method (_GRT, 0, Serialized)
            {
              Name (RTIM, Buffer (0x10)
              {
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
              })
              CreateByteField (RTIM, Zero, YERL)
              CreateByteField (RTIM, 0x01, YERH)
              CreateByteField (RTIM, 0x02, MON)
              CreateByteField (RTIM, 0x03, DAY)
              CreateByteField (RTIM, 0x04, HOUR)
              CreateByteField (RTIM, 0x05, MIN)
              CreateByteField (RTIM, 0x06, SEC)
              CreateByteField (RTIM, 0x07, VAL)
              CreateByteField (RTIM, 0x08, MILS)
              CreateByteField (RTIM, 0x0a, TZL)
              CreateByteField (RTIM, 0x0b, TZH)
              CreateByteField (RTIM, 0x0c, DST)

              Acquire (MCTX, 0xFFFF)
              Store (DE2H(CSEC), SEC)
              Store (DE2H(CMIN), MIN)
              Store (DE2H(CHOU), HOUR)
              Store (DE2H(CDAY), DAY)
              Store (DE2H(CMON), MON)
              ShiftRight(YCEN(CYEA), 8, YERH)
              Store (YCEN(CYEA), YERL)
	      E2TZ (RTIM)		// Transfer minutes east of UTC to ACPI TZ
              UT2L(RTIM)                // Transfer UTC to Local time
		Store ("CDST", Debug)
		Store (CDST, Debug)
		Store ("CTZL", Debug)
		Store (CTZL, Debug)
		Store ("CTZH", Debug)
		Store (CTZH, Debug)
              Store (CDST, DST)
              Release (MCTX)
              Return (RTIM)
            }

            Method (_SRT, 1, Serialized)
            {
              CreateByteField (Arg0, Zero, YERL)
              CreateByteField (Arg0, 0x01, YERH)
              CreateByteField (Arg0, 0x02, MON)
              CreateByteField (Arg0, 0x03, DAY)
              CreateByteField (Arg0, 0x04, HOUR)
              CreateByteField (Arg0, 0x05, MIN)
              CreateByteField (Arg0, 0x06, SEC)
              CreateByteField (Arg0, 0x0a, TZL)
              CreateByteField (Arg0, 0x0b, TZH)
              CreateByteField (Arg0, 0x0c, DST)

              Acquire (MCTX, 0xFFFF)
              LT2U (Arg0)               // Transfer Local time to UTC
              Store (HE2D(YEAC(YERL, YERH)), CYEA)
              Store (HE2D(MON), CMON)
              Store (HE2D(DAY), CDAY)
              Store (HE2D(HOUR), CHOU)
              Store (HE2D(MIN), CMIN)
              Store (HE2D(SEC), CSEC)
	      TZ2E (Arg0)		// Transfer ACPI TZ to minutes east of UTC and set to CMOS
              Store (DST, CDST)
              Release (MCTX)
              Return (0x00000000)
            }

            Method (_GWS, 1, Serialized)
            {
                Return (0x00000000)
            }

            Method (_CWS, 1, Serialized)
            {
                Return (0x00000001)
            }

            Method (_STP, 2, Serialized)
            {
                Return (0x00000001)
            }

            Method (_STV, 2, Serialized)
            {
                Return (0x00000001)
            }

            Method (_TIP, 1, Serialized)
            {
                Return (0xFFFFFFFF)
            }

            Method (_TIV, 1, Serialized)
            {
                Return (0xFFFFFFFF)
            }
        }
    }

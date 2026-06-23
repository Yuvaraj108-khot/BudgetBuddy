package com.yuvaraj.budget_buddy

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.telephony.SmsMessage
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.yuvaraj.budget_buddy/sms"
    private var smsReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    smsReceiver = object : BroadcastReceiver() {
                        override fun onReceive(context: Context?, intent: Intent?) {
                            if (intent?.action == "android.provider.Telephony.SMS_RECEIVED") {
                                val bundle: Bundle? = intent.extras
                                if (bundle != null) {
                                    try {
                                        val pdus = bundle.get("pdus") as Array<*>
                                        for (i in pdus.indices) {
                                            val format = bundle.getString("format")
                                            val message = SmsMessage.createFromPdu(pdus[i] as ByteArray, format)
                                            val sender = message.originatingAddress
                                            val body = message.messageBody
                                            
                                            val smsData = mapOf(
                                                "sender" to sender,
                                                "body" to body
                                            )
                                            events?.success(smsData)
                                        }
                                    } catch (e: Exception) {
                                        e.printStackTrace()
                                    }
                                }
                            }
                        }
                    }
                    val filter = IntentFilter("android.provider.Telephony.SMS_RECEIVED")
                    context.registerReceiver(smsReceiver, filter)
                }

                override fun onCancel(arguments: Any?) {
                    if (smsReceiver != null) {
                        try {
                            context.unregisterReceiver(smsReceiver)
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                        smsReceiver = null
                    }
                }
            }
        )
    }
}

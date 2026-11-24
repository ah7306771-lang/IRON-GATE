#!/usr/bin/env bash
# اختبار سريع لـ shipment-track.  الاستخدام:
#   TOKEN=رمز_الرابط ./smoke-test.sh                # اختبارات القراءة والرفض فقط (آمنة)
#   TOKEN=رمز_الرابط RUN_WRITE=1 ./smoke-test.sh    # يضيف توقيع وتقييم حقيقيين على الشحنة (استخدم شحنة تجريبية!)
API="${API:-https://wadovjghevemdmqkhhml.supabase.co/functions/v1/shipment-track}"
: "${TOKEN:?ضع TOKEN=...}"
PNG="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
pass=0; fail=0
check() { # name expected_code body
  code=$(curl -s -o /tmp/resp.json -w "%{http_code}" -X POST "$API" -H 'Content-Type: application/json' -d "$3")
  if [ "$code" = "$2" ]; then echo "PASS  $1 ($code)"; pass=$((pass+1)); else echo "FAIL  $1 (expected $2, got $code): $(cat /tmp/resp.json)"; fail=$((fail+1)); fi
}
code=$(curl -s -o /tmp/resp.json -w "%{http_code}" "$API?token=$TOKEN")
[ "$code" = "200" ] && { echo "PASS  GET tracking (200)"; pass=$((pass+1)); } || { echo "FAIL  GET tracking ($code): $(cat /tmp/resp.json)"; fail=$((fail+1)); }
check "رفض توقيع بدون اسم"            400 "{\"action\":\"customer_signature\",\"token\":\"$TOKEN\",\"signature\":\"$PNG\"}"
check "رفض ملاحظة فاضية"              400 "{\"action\":\"customer_signature\",\"token\":\"$TOKEN\",\"signature\":\"$PNG\",\"receiverName\":\"اختبار\",\"hasIssue\":true,\"note\":\"\"}"
check "رفض ملف مش PNG"               400 "{\"action\":\"customer_signature\",\"token\":\"$TOKEN\",\"signature\":\"data:image/png;base64,AAAA\",\"receiverName\":\"اختبار\"}"
check "رفض تقييم 6 نجوم"              400 "{\"action\":\"customer_rating\",\"token\":\"$TOKEN\",\"stars\":6}"
check "رفض توكن غلط"                  400 "{\"action\":\"customer_rating\",\"token\":\"bad\",\"stars\":5}"
if [ -n "$RUN_WRITE" ]; then
  echo "-- اختبارات كتابة (الشحنة لازم تكون متسلّمة) --"
  check "توقيع صحيح"                  200 "{\"action\":\"customer_signature\",\"token\":\"$TOKEN\",\"signature\":\"$PNG\",\"receiverName\":\"اختبار\",\"hasIssue\":true,\"note\":\"نقص بسيط\"}"
  check "توقيع تاني مرفوض"            409 "{\"action\":\"customer_signature\",\"token\":\"$TOKEN\",\"signature\":\"$PNG\",\"receiverName\":\"اختبار\"}"
  check "تقييم صحيح"                  200 "{\"action\":\"customer_rating\",\"token\":\"$TOKEN\",\"stars\":5,\"comment\":\"ممتاز\"}"
  check "تقييم تاني مرفوض"            409 "{\"action\":\"customer_rating\",\"token\":\"$TOKEN\",\"stars\":4}"
fi
echo "النتيجة: $pass نجح / $fail فشل"; [ $fail -eq 0 ]

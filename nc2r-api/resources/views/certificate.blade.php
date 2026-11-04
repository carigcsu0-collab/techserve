<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        @page { margin: 0; }
        body {
            margin: 0;
            font-family: 'DejaVu Serif', serif;
            text-align: center;
        }
        .frame {
            border: 12px solid #800000;
            padding: 8px;
            height: 100%;
        }
        .inner {
            border: 2px solid #c9a227;
            padding: 60px 40px;
        }
        .brand {
            font-size: 14px;
            letter-spacing: 6px;
            color: #800000;
            text-transform: uppercase;
        }
        h1 {
            font-size: 42px;
            color: #800000;
            margin: 18px 0 6px;
            letter-spacing: 2px;
        }
        .subtitle {
            font-size: 14px;
            color: #555;
            margin-bottom: 30px;
        }
        .presented { font-size: 12px; color: #777; text-transform: uppercase; letter-spacing: 3px; }
        .name {
            font-size: 34px;
            font-weight: bold;
            color: #222;
            margin: 14px 0;
            border-bottom: 1px solid #c9a227;
            display: inline-block;
            padding: 0 40px 8px;
        }
        .course { font-size: 16px; color: #444; margin-top: 24px; }
        .course strong { color: #800000; }
        .meta {
            margin-top: 60px;
            font-size: 12px;
            color: #666;
        }
        .meta td { padding: 0 60px; }
        .sig-line {
            border-top: 1px solid #999;
            padding-top: 4px;
            width: 180px;
        }
    </style>
</head>
<body>
    <div class="frame">
        <div class="inner">
            <div class="brand">NC2R &mdash; NC II Reviewer</div>
            <h1>Certificate of Completion</h1>
            <div class="subtitle">This certificate is proudly presented to</div>

            <div class="presented">&nbsp;</div>
            <div class="name">{{ $name }}</div>

            <div class="course">
                for successfully completing all lessons and assessments in<br>
                <strong>{{ $course }}</strong>
            </div>

            <table class="meta" width="100%">
                <tr>
                    <td><div class="sig-line">{{ $date }}<br>Date Issued</div></td>
                    <td><div class="sig-line">{{ $certificateId }}<br>Certificate ID</div></td>
                </tr>
            </table>
        </div>
    </div>
</body>
</html>

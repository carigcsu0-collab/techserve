<?php

namespace Database\Seeders;

use App\Models\Lesson;
use App\Models\Question;
use Illuminate\Database\Seeder;

class LessonSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * Each quiz has a different number of questions and a mix of types:
     * multiple_choice (options + exact match), true_false, and
     * identification (free text, graded case-insensitively).
     */
    public function run(): void
    {
        $lessons = [
            [
                'title' => 'Introduction to Computer Systems Servicing',
                'description' => 'Overview of the NC II qualification, core competencies, and safety practices.',
                'media_url' => 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
                'media_type' => 'video',
                'order_index' => 1,
                'passing_score' => 70,
                'questions' => [
                    [
                        'question_text' => 'What does NC II stand for?',
                        'question_type' => Question::TYPE_MULTIPLE_CHOICE,
                        'options' => ['National Certification Level II', 'Network Certificate II', 'New Course II', 'National Competency II'],
                        'correct_answer' => 'National Certification Level II',
                    ],
                    [
                        'question_text' => 'You should remove the power source before opening a computer case.',
                        'question_type' => Question::TYPE_TRUE_FALSE,
                        'options' => ['True', 'False'],
                        'correct_answer' => 'True',
                    ],
                    [
                        'question_text' => 'What personal protective equipment protects your eyes while working?',
                        'question_type' => Question::TYPE_IDENTIFICATION,
                        'options' => null,
                        'correct_answer' => 'Safety goggles',
                    ],
                ],
            ],
            [
                'title' => 'Computer Hardware Components',
                'description' => 'Identify and describe the function of motherboard, CPU, RAM, storage, and PSU.',
                'media_url' => 'https://picsum.photos/seed/hardware/1280/720',
                'media_type' => 'image',
                'order_index' => 2,
                'passing_score' => 70,
                'questions' => [
                    [
                        'question_text' => 'Which component is considered the brain of the computer?',
                        'question_type' => Question::TYPE_MULTIPLE_CHOICE,
                        'options' => ['CPU', 'RAM', 'PSU', 'HDD'],
                        'correct_answer' => 'CPU',
                    ],
                    [
                        'question_text' => 'What does RAM stand for?',
                        'question_type' => Question::TYPE_MULTIPLE_CHOICE,
                        'options' => ['Random Access Memory', 'Read Access Memory', 'Rapid Action Module', 'Remote Array Memory'],
                        'correct_answer' => 'Random Access Memory',
                    ],
                    [
                        'question_text' => 'Which component supplies power to the system?',
                        'question_type' => Question::TYPE_MULTIPLE_CHOICE,
                        'options' => ['PSU', 'GPU', 'BIOS', 'NIC'],
                        'correct_answer' => 'PSU',
                    ],
                    [
                        'question_text' => 'RAM loses its contents when the computer is powered off.',
                        'question_type' => Question::TYPE_TRUE_FALSE,
                        'options' => ['True', 'False'],
                        'correct_answer' => 'True',
                    ],
                    [
                        'question_text' => 'What component connects all hardware parts together?',
                        'question_type' => Question::TYPE_IDENTIFICATION,
                        'options' => null,
                        'correct_answer' => 'Motherboard',
                    ],
                ],
            ],
            [
                'title' => 'Operating System Installation',
                'description' => 'Step-by-step guide to preparing bootable media and installing an operating system.',
                'media_url' => 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
                'media_type' => 'video',
                'order_index' => 3,
                'passing_score' => 70,
                'questions' => [
                    [
                        'question_text' => 'What tool is commonly used to create a bootable USB drive?',
                        'question_type' => Question::TYPE_MULTIPLE_CHOICE,
                        'options' => ['Rufus', 'Notepad', 'Excel', 'Paint'],
                        'correct_answer' => 'Rufus',
                    ],
                    [
                        'question_text' => 'Where do you configure which device boots first?',
                        'question_type' => Question::TYPE_MULTIPLE_CHOICE,
                        'options' => ['BIOS/UEFI settings', 'Task Manager', 'Control Panel', 'File Explorer'],
                        'correct_answer' => 'BIOS/UEFI settings',
                    ],
                    [
                        'question_text' => 'What file system does Windows typically use for OS partitions?',
                        'question_type' => Question::TYPE_IDENTIFICATION,
                        'options' => null,
                        'correct_answer' => 'NTFS',
                    ],
                ],
            ],
            [
                'title' => 'Network Configuration Basics',
                'description' => 'Learn IP addressing, subnet masks, and basic network troubleshooting.',
                'media_url' => 'https://picsum.photos/seed/network/1280/720',
                'media_type' => 'image',
                'order_index' => 4,
                'passing_score' => 70,
                'questions' => [
                    [
                        'question_text' => 'Which command displays your current IP configuration on Windows?',
                        'question_type' => Question::TYPE_MULTIPLE_CHOICE,
                        'options' => ['ipconfig', 'ping', 'tracert', 'netstat'],
                        'correct_answer' => 'ipconfig',
                    ],
                    [
                        'question_text' => 'What is the default subnet mask for a Class C network?',
                        'question_type' => Question::TYPE_MULTIPLE_CHOICE,
                        'options' => ['255.255.255.0', '255.0.0.0', '255.255.0.0', '255.255.255.255'],
                        'correct_answer' => '255.255.255.0',
                    ],
                    [
                        'question_text' => 'Which device connects multiple networks together?',
                        'question_type' => Question::TYPE_MULTIPLE_CHOICE,
                        'options' => ['Router', 'Switch', 'Hub', 'Repeater'],
                        'correct_answer' => 'Router',
                    ],
                    [
                        'question_text' => 'A switch operates at Layer 3 of the OSI model.',
                        'question_type' => Question::TYPE_TRUE_FALSE,
                        'options' => ['True', 'False'],
                        'correct_answer' => 'False',
                    ],
                    [
                        'question_text' => 'What protocol automatically assigns IP addresses to devices?',
                        'question_type' => Question::TYPE_IDENTIFICATION,
                        'options' => null,
                        'correct_answer' => 'DHCP',
                    ],
                    [
                        'question_text' => 'Which IPv4 address is the loopback address?',
                        'question_type' => Question::TYPE_MULTIPLE_CHOICE,
                        'options' => ['127.0.0.1', '192.168.1.1', '8.8.8.8', '0.0.0.0'],
                        'correct_answer' => '127.0.0.1',
                    ],
                ],
            ],
        ];

        foreach ($lessons as $data) {
            $questions = $data['questions'];
            $passingScore = $data['passing_score'];
            unset($data['questions'], $data['passing_score']);

            $lesson = Lesson::updateOrCreate(
                ['order_index' => $data['order_index']],
                $data,
            );

            $quiz = $lesson->quiz()->updateOrCreate(
                [],
                ['passing_score' => $passingScore],
            );

            $quiz->questions()->delete();
            $quiz->questions()->createMany($questions);
        }
    }
}

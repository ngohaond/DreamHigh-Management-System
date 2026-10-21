import { NotFoundException } from '@nestjs/common';
import { ClassesService } from './classes.service';
import type { PrismaService } from '../../prisma/prisma.service';

describe('ClassesService.getClassDetails', () => {
  let service: ClassesService;
  const prisma = {
    trainingClass: {
      findUnique: jest.fn(),
    },
  } as unknown as PrismaService;

  beforeEach(() => {
    jest.clearAllMocks();
    service = new ClassesService(prisma);
  });

  it('throws NotFoundException when class code does not exist', async () => {
    (prisma.trainingClass.findUnique as jest.Mock).mockResolvedValue(null);

    await expect(service.getClassDetails('XXXX')).rejects.toBeInstanceOf(NotFoundException);
  });

  it('returns class detail with course, sessions and enrollments', async () => {
    const classInfo = {
      id: 1,
      classCode: 'PY-K1-01',
      course: { id: 1, name: 'Python Kids 1' },
      teacher: null,
      sessions: [{ id: 1, startTime: new Date('2026-03-02T02:00:00Z') }],
      exams: [],
      enrollments: [{ id: 1 }],
    };
    (prisma.trainingClass.findUnique as jest.Mock).mockResolvedValue(classInfo);

    const result = await service.getClassDetails('PY-K1-01');

    expect(result.statusCode).toBe(200);
    expect(result.data.classCode).toBe('PY-K1-01');
    expect(result.data.course.name).toBe('Python Kids 1');
    expect(result.data.sessions).toHaveLength(1);
    expect(result.data.enrollments).toHaveLength(1);
  });

  it('does not expose teacher passwordHash or googleSub', async () => {
    const classInfo = {
      id: 1,
      classCode: 'PY-K1-01',
      course: { id: 1 },
      teacher: {
        id: 7,
        fullName: 'Nguyễn Văn A',
        email: 'a@dreamhigh.vn',
        passwordHash: 'super-secret-hash',
        googleSub: 'google-oauth-sub-123',
      },
      sessions: [],
      exams: [],
      enrollments: [],
    };
    (prisma.trainingClass.findUnique as jest.Mock).mockResolvedValue(classInfo);

    const result = await service.getClassDetails('PY-K1-01');

    expect(result.data.teacher).not.toHaveProperty('passwordHash');
    expect(result.data.teacher).not.toHaveProperty('googleSub');
    expect(result.data.teacher.fullName).toBe('Nguyễn Văn A');
    expect(result.data.teacher.roles).toEqual([]);
  });

  it('returns null teacher when class has no teacher relation', async () => {
    (prisma.trainingClass.findUnique as jest.Mock).mockResolvedValue({
      id: 1,
      classCode: 'PY-K1-01',
      course: { id: 1 },
      teacher: null,
      sessions: [],
      exams: [],
      enrollments: [],
    });

    const result = await service.getClassDetails('PY-K1-01');

    expect(result.data.teacher).toBeNull();
  });
});

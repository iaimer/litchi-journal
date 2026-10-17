export class DiaryWriteError extends Error {
  constructor(message: string, readonly statusCode = 409) {
    super(message);
    this.name = 'DiaryWriteError';
  }
}
